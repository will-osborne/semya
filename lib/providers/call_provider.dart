import 'dart:async';
import 'dart:io';

import 'package:semya/data/services/call_debug_log.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:semya/data/services/call_sound_service.dart';
import 'package:semya/data/services/callkit_service.dart';
import 'package:semya/data/services/webrtc_service.dart';
import 'package:semya/domain/entities/call.dart';
import 'package:semya/domain/repositories/call_repository.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/providers.dart';

/// Error message set when microphone permission is denied. The
/// IncomingCallOverlay matches on this value to show a localized, actionable
/// snackbar (with an Open Settings shortcut) instead of a generic failure.
const kCallMicPermissionError = 'Microphone permission required';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class CallState {
  const CallState({
    this.activeCall,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isConnecting = false,
    this.isVideoEnabled = false,
    this.hasRemoteVideo = false,
    this.callDuration = Duration.zero,
    this.error,
  });

  final Call? activeCall;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isConnecting;
  final bool isVideoEnabled;
  final bool hasRemoteVideo;
  final Duration callDuration;
  final String? error;

  CallState copyWith({
    Call? activeCall,
    bool clearActiveCall = false,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isConnecting,
    bool? isVideoEnabled,
    bool? hasRemoteVideo,
    Duration? callDuration,
    String? error,
    bool clearError = false,
  }) {
    return CallState(
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isConnecting: isConnecting ?? this.isConnecting,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      hasRemoteVideo: hasRemoteVideo ?? this.hasRemoteVideo,
      callDuration: callDuration ?? this.callDuration,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class CallNotifier extends StateNotifier<CallState> {
  CallNotifier({
    required CallRepository callRepository,
    required WebRtcService webRtcService,
    required CallSoundService callSoundService,
    required CallKitService callKitService,
    required VoiceNoteStopCallback stopVoicePlayback,
  }) : _callRepository = callRepository,
       _webRtcService = webRtcService,
       _callSoundService = callSoundService,
       _callKitService = callKitService,
       _stopVoicePlayback = stopVoicePlayback,
       super(const CallState());

  final CallRepository _callRepository;
  final WebRtcService _webRtcService;
  final CallSoundService _callSoundService;
  final CallKitService _callKitService;
  final VoiceNoteStopCallback _stopVoicePlayback;

  // ── Subscriptions ──────────────────────────────────────────────────────────
  // Single call-doc subscription — handles status, signaling, and ICE restart.
  StreamSubscription<Call?>? _callSub;
  StreamSubscription<List<IceCandidate>>? _remoteCandidateSub;
  StreamSubscription<RTCIceCandidate>? _localCandidateSub;
  StreamSubscription<RTCPeerConnectionState>? _connectionStateSub;
  StreamSubscription<bool>? _remoteVideoSub;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _ringTimeout;
  Timer? _durationTimer;
  Timer? _disconnectGraceTimer;

  // ── Session state ─────────────────────────────────────────────────────────
  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  bool _isCleaningUp = false;
  bool _durationTimerStarted = false;

  // One-shot guard for the Firestore status=connected transition (stop dial
  // tone, configure audio, notify CallKit). Separate from
  // _durationTimerStarted, which is owned by the WebRTC connection state —
  // without its own flag this block re-ran on every call-doc update (e.g.
  // video toggles) between Firestore-connected and ICE-connected.
  bool _connectedHandled = false;

  // Guards concurrent setRemoteDescription calls from overlapping stream events.
  bool _settingDescription = false;

  // Initial handshake: true once the caller has applied the callee's answer.
  bool _remoteDescriptionSet = false;

  // ── ICE candidate management ──────────────────────────────────────────────
  final Set<String> _processedCandidateIds = {};

  // Remote candidates buffered while setRemoteDescription hasn't completed yet.
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  // Remote candidates whose addIceCandidate failed (e.g. new-generation
  // candidates rejected against the pre-restart ufrag during an ICE restart).
  // Re-attempted after every setRemoteDescription — their ids stay in
  // _processedCandidateIds, so without this list they would never be retried.
  final List<RTCIceCandidate> _failedRemoteCandidates = [];

  // Caller-side: true from the moment an ICE restart offer is created until
  // the callee's restart answer is applied. New-generation candidates arriving
  // in that window must be buffered — adding them immediately fails silently
  // against the old ufrag. (The callee side is covered by _settingDescription
  // plus the _failedRemoteCandidates retry above.)
  bool _iceRestartBuffering = false;

  // Serialised queue for local ICE candidate Firestore writes.
  final List<(String, IceCandidate)> _localCandidateQueue = [];
  bool _processingLocalCandidates = false;

  // ── ICE restart deduplication ─────────────────────────────────────────────
  // Caller: SDP of the restart offer we wrote, waiting for callee's answer.
  // Cleared once the answer is applied, or if the restart attempt fails.
  String? _pendingRestartOfferSdp;

  // Callee: SDP of the last restart offer we fully processed (offer received
  // → answer written). Prevents re-processing the same offer when unrelated
  // call-doc fields change and trigger another _onCallUpdate.
  String? _lastProcessedRestartSdp;

  bool _iceRestarting = false;

  static const _uuid = Uuid();
  static const _ringTimeoutDuration = Duration(seconds: 45);
  static const _disconnectGracePeriod = Duration(seconds: 20);
  static const _failedGracePeriod = Duration(seconds: 12);
  static const _offerWaitTimeout = Duration(seconds: 30);
  static const _maxWriteAttempts = 3;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// Start an outgoing call.
  Future<void> initiateCall({
    required String calleeId,
    required String conversationId,
    required String currentUserId,
  }) async {
    if (state.activeCall != null || state.isConnecting) return;

    _currentUserId = currentUserId;

    // Glare: both users dialing each other at once creates two competing
    // docs — each side's activeCall suppresses the other's ring and both
    // time out. If the other party is already ringing us, answer their call
    // instead of creating a new one.
    try {
      final existing = await _callRepository.getRingingCallBetween(
        callerId: calleeId,
        calleeId: currentUserId,
      );
      if (existing != null) {
        CallDebugLog.add(
          'Glare detected: answering incoming call ${existing.id} from '
          '$calleeId instead of dialing',
          name: 'Call',
        );
        await answerCall(existing.id);
        return;
      }
    } catch (e) {
      CallDebugLog.add(
        'Glare check failed, proceeding with outgoing call: $e',
        name: 'Call',
      );
    }

    if (!await _ensureMicrophonePermission()) {
      state = state.copyWith(error: kCallMicPermissionError);
      return;
    }

    _resetSessionState();
    state = state.copyWith(isConnecting: true, clearError: true);
    String? createdCallId;

    try {
      await _stopVoicePlayback();

      final callId = _uuid.v4();
      createdCallId = callId;

      final call = Call(
        id: callId,
        callerId: currentUserId,
        calleeId: calleeId,
        participantIds: [currentUserId, calleeId],
        conversationId: conversationId,
        status: CallStatus.ringing,
        createdAt: DateTime.now(),
      );

      await _retryWrite(
        operation: 'createCall',
        action: () => _callRepository.createCall(call),
      );
      state = state.copyWith(activeCall: call);

      // Report the outgoing call to CallKit so it activates the audio session
      // (triggers didActivateAudioSession in AppDelegate). Without this,
      // useManualAudio keeps WebRTC audio disabled on iOS.
      if (Platform.isIOS) {
        await _callKitService.startCall(callId, calleeId);
      }

      // Fetch TURN credentials and play dial tone concurrently.
      final turnFuture = _fetchTurnCredentials();
      _callSoundService.playDialTone();

      final turnCredentials = await turnFuture;
      CallDebugLog.add('webRtcService.initialize() starting', name: 'Call');
      await _webRtcService.initialize(
        iceServers: turnCredentials,
        captureVideo: await Permission.camera.isGranted,
      );
      CallDebugLog.add('webRtcService.initialize() done', name: 'Call');

      // Subscribe to local ICE candidates BEFORE creating the offer so no
      // candidates are lost from the broadcast stream.
      _localCandidateSub = _webRtcService.localCandidates.listen((candidate) {
        _enqueueLocalCandidate(callId, currentUserId, candidate);
      });

      CallDebugLog.add('createOffer() starting', name: 'Call');
      final offer = await _webRtcService.createOffer();
      CallDebugLog.add('createOffer() done', name: 'Call');
      await _retryWrite(
        operation: 'setOffer',
        action: () => _callRepository.setOffer(callId, {
          'sdp': offer.sdp,
          'type': offer.type,
        }),
      );

      // Single call-doc subscription handles status changes, callee's answer,
      // and ICE restart answers — all via _onCallUpdate.
      _callSub = _callRepository.watchCall(callId).listen(_onCallUpdate);

      // Watch ICE candidates from the callee. Candidates arriving before the
      // remote description is set are buffered and flushed in _onCallUpdate.
      _remoteCandidateSub = _callRepository
          .watchIceCandidates(callId, calleeId)
          .listen(_onRemoteCandidates);

      _connectionStateSub = _webRtcService.connectionState.listen(
        _onConnectionState,
      );
      _remoteVideoSub = _webRtcService.remoteVideoStream.listen((hasVideo) {
        state = state.copyWith(hasRemoteVideo: hasVideo);
      });

      _ringTimeout = Timer(_ringTimeoutDuration, _onRingTimeout);
    } on CallSetupException catch (e, st) {
      CallDebugLog.add('initiateCall setup failed: ${e.message} cause=${e.cause}\n$st', name: 'Call');
      final callId = createdCallId ?? state.activeCall?.id;
      if (callId != null) await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = CallState(error: e.message);
    } catch (e, st) {
      CallDebugLog.add('initiateCall failed: $e\n$st', name: 'Call');
      final callId = createdCallId ?? state.activeCall?.id;
      if (callId != null) await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = const CallState(error: 'Failed to start call');
    }
  }

  /// Answer an incoming call.
  Future<void> answerCall(String callId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    if (state.activeCall != null || state.isConnecting) return;

    if (!await _ensureMicrophonePermission()) {
      await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = state.copyWith(error: kCallMicPermissionError);
      return;
    }

    await _attemptAnswerCall(callId, uid, attempt: 1);
  }

  Future<void> _attemptAnswerCall(
    String callId,
    String uid, {
    required int attempt,
  }) async {
    _resetSessionState();
    state = state.copyWith(isConnecting: true, clearError: true);

    try {
      await _stopVoicePlayback();

      final turnFuture = _fetchTurnCredentials();
      if (Platform.isAndroid) {
        _callSoundService.configureForVoiceCall();
      }

      final turnCredentials = await turnFuture;
      CallDebugLog.add('answerCall: webRtcService.initialize() starting', name: 'Call');
      await _webRtcService.initialize(
        iceServers: turnCredentials,
        captureVideo: await Permission.camera.isGranted,
      );
      CallDebugLog.add('answerCall: webRtcService.initialize() done', name: 'Call');

      // Subscribe to local ICE candidates BEFORE creating the answer.
      _localCandidateSub = _webRtcService.localCandidates.listen((candidate) {
        _enqueueLocalCandidate(callId, uid, candidate);
      });

      // Wait for the caller's offer to appear in Firestore.
      final call = await _callRepository
          .watchCall(callId)
          .where((c) => c != null && c.offer != null)
          .first
          .timeout(_offerWaitTimeout);

      if (call == null || call.offer == null) {
        await _endCallWithError(callId);
        await _cleanup(callId: callId);
        state = const CallState(error: 'Call not found');
        return;
      }

      if (call.status != CallStatus.ringing) {
        await _cleanup(callId: callId);
        state = const CallState(error: 'Call no longer available');
        return;
      }

      state = state.copyWith(activeCall: call);

      await _webRtcService.setRemoteDescription(
        RTCSessionDescription(
          call.offer!['sdp'] as String,
          call.offer!['type'] as String,
        ),
      );
      _remoteDescriptionSet = true;
      await _flushPendingCandidates();

      // Subscribe to all streams BEFORE writing to Firestore so that any
      // status change from the caller (e.g. hang-up) arriving during the
      // async writes below is not missed.
      _remoteCandidateSub = _callRepository
          .watchIceCandidates(callId, call.callerId)
          .listen(_onRemoteCandidates);
      _callSub = _callRepository.watchCall(callId).listen(_onCallUpdate);
      _connectionStateSub = _webRtcService.connectionState.listen(
        _onConnectionState,
      );
      _remoteVideoSub = _webRtcService.remoteVideoStream.listen((hasVideo) {
        state = state.copyWith(hasRemoteVideo: hasVideo);
      });

      final answer = await _webRtcService.createAnswer();
      await _retryWrite(
        operation: 'setAnswer',
        action: () => _callRepository.setAnswer(callId, {
          'sdp': answer.sdp,
          'type': answer.type,
        }),
      );
      await _retryWrite(
        operation: 'updateCall(status=connected)',
        action: () => _callRepository.updateCall(callId, {
          'status': CallStatus.connected.name,
        }),
      );
    } on TimeoutException {
      // The offer never arrived — retrying would just wait on a dead call.
      CallDebugLog.add('answerCall timed out waiting for offer', name: 'Call');
      await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = const CallState(error: 'Call timed out');
    } on CallSetupException catch (e, st) {
      CallDebugLog.add(
        'answerCall setup failed (attempt $attempt): ${e.message} '
        'cause=${e.cause}\n$st',
        name: 'Call',
      );
      if (await _retryAnswerAfterFailure(callId, uid, attempt)) return;
      await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = CallState(error: e.message);
    } catch (e, st) {
      CallDebugLog.add('answerCall failed (attempt $attempt): $e\n$st', name: 'Call');
      if (await _retryAnswerAfterFailure(callId, uid, attempt)) return;
      await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = const CallState(error: 'Failed to answer call');
    }
  }

  /// One retry for transient callee-side setup failures — without it a single
  /// hiccup (TURN fetch, getUserMedia race, Firestore blip) ends the call for
  /// BOTH sides. Returns true when a retry was started.
  Future<bool> _retryAnswerAfterFailure(
    String callId,
    String uid,
    int attempt,
  ) async {
    if (attempt >= 2) return false;

    // Only retry while the call is still answerable.
    try {
      final call = await _callRepository.getCall(callId);
      if (call == null || call.status != CallStatus.ringing) return false;
    } catch (_) {
      return false;
    }

    CallDebugLog.add(
      'answerCall: retrying setup (attempt ${attempt + 1})',
      name: 'Call',
    );
    // Tear down the failed session but keep the native call UI alive.
    await _cleanup(callId: callId, dismissCallKit: false);
    state = const CallState();
    await _attemptAnswerCall(callId, uid, attempt: attempt + 1);
    return true;
  }

  /// Loads an existing call into state (e.g. when navigating from a
  /// notification). If still ringing, answers it. If already connected,
  /// observes it without re-answering.
  Future<void> joinCall(String callId) async {
    if (state.activeCall?.id == callId) return;
    if (state.isConnecting) return;

    final uid = _currentUserId;
    if (uid == null) return;

    final call = await _callRepository.getCall(callId);
    if (call == null) {
      state = state.copyWith(error: 'Call not found');
      return;
    }

    if (call.status == CallStatus.ended ||
        call.status == CallStatus.missed ||
        call.status == CallStatus.rejected) {
      state = state.copyWith(error: 'Call already ended');
      return;
    }

    if (call.calleeId == uid && call.status == CallStatus.ringing) {
      await answerCall(callId);
      return;
    }

    state = state.copyWith(activeCall: call);
    _callSub = _callRepository.watchCall(callId).listen(_onCallUpdate);
  }

  /// Reject an incoming call without answering.
  Future<void> rejectCall(String callId) async {
    await _retryWrite(
      operation: 'updateCall(status=rejected)',
      action: () => _callRepository.updateCall(callId, {
        'status': CallStatus.rejected.name,
        'endedAt': DateTime.now().toIso8601String(),
        'endReason': CallEndReason.rejected.name,
      }),
    );
  }

  /// Hang up the current call.
  Future<void> hangUp() async {
    final call = state.activeCall;
    if (call != null) {
      // Cancel listener first to prevent double-cleanup from _onCallUpdate
      // reacting to the status change we are about to write.
      await _callSub?.cancel();
      _callSub = null;

      await _retryWrite(
        operation: 'updateCall(status=ended)',
        action: () => _callRepository.updateCall(call.id, {
          'status': CallStatus.ended.name,
          'endedAt': DateTime.now().toIso8601String(),
          'endReason': CallEndReason.hangUp.name,
        }),
      );
    }
    await _cleanup();
    state = const CallState();
  }

  void toggleMute() {
    _webRtcService.toggleMute();
    state = state.copyWith(isMuted: _webRtcService.isMuted);
  }

  Future<void> toggleSpeaker() async {
    await _webRtcService.toggleSpeaker();
    state = state.copyWith(isSpeakerOn: _webRtcService.isSpeakerOn);
  }

  Future<void> toggleVideo() async {
    final success = await _webRtcService.toggleVideo();
    if (!success) return;

    state = state.copyWith(
      isVideoEnabled: _webRtcService.isVideoEnabled,
      isSpeakerOn: _webRtcService.isSpeakerOn,
    );

    final call = state.activeCall;
    if (call != null) {
      final isCaller = call.callerId == _currentUserId;
      final field = isCaller ? 'callerVideoEnabled' : 'calleeVideoEnabled';
      await _retryWrite(
        operation: 'updateCall(videoState)',
        action: () => _callRepository.updateCall(call.id, {
          field: _webRtcService.isVideoEnabled,
        }),
      );
    }
  }

  Future<void> switchCamera() async {
    await _webRtcService.switchCamera();
  }

  // ---------------------------------------------------------------------------
  // Call-doc event handler (single subscription)
  // ---------------------------------------------------------------------------

  Future<void> _onCallUpdate(Call? call) async {
    if (call == null || _isCleaningUp) return;

    final isCaller = call.callerId == _currentUserId;
    final remoteVideoEnabled = isCaller
        ? call.calleeVideoEnabled
        : call.callerVideoEnabled;

    state = state.copyWith(
      activeCall: call,
      hasRemoteVideo: remoteVideoEnabled,
    );

    // ── Initial handshake: caller applies callee's answer ──────────────────
    if (isCaller &&
        call.answer != null &&
        !_remoteDescriptionSet &&
        !_settingDescription) {
      _settingDescription = true;
      try {
        await _webRtcService.setRemoteDescription(
          RTCSessionDescription(
            call.answer!['sdp'] as String,
            call.answer!['type'] as String,
          ),
        );
        _remoteDescriptionSet = true;
        await _flushPendingCandidates();
      } catch (e) {
        CallDebugLog.add('Failed to apply callee answer: $e', name: 'Call');
      } finally {
        _settingDescription = false;
      }
    }

    // ── ICE restart negotiation ────────────────────────────────────────────
    // Handled entirely within this single subscription, using SDP-based
    // deduplication to prevent re-processing the same offer/answer when
    // unrelated call-doc fields change.
    if (!_settingDescription) {
      if (isCaller) {
        // Caller: apply the callee's restart answer — exactly once per
        // pending restart offer.
        final restartOfferSdp = call.restartOffer?['sdp'] as String?;
        if (_pendingRestartOfferSdp != null &&
            restartOfferSdp == _pendingRestartOfferSdp &&
            call.restartAnswer != null) {
          final sentOfferSdp = _pendingRestartOfferSdp!;
          // Clear immediately to prevent re-entry before the await completes.
          _pendingRestartOfferSdp = null;
          _settingDescription = true;
          try {
            await _webRtcService.setRemoteDescription(
              RTCSessionDescription(
                call.restartAnswer!['sdp'] as String,
                call.restartAnswer!['type'] as String,
              ),
            );
            // Restart negotiation complete — release the candidate buffer.
            _iceRestartBuffering = false;
            await _flushPendingCandidates();
            CallDebugLog.add(
              'ICE restart: applied callee answer, buffered candidates flushed',
              name: 'Call',
            );
          } catch (e) {
            CallDebugLog.add('ICE restart: failed to apply answer: $e', name: 'Call');
            // Restore so we can retry on the next update.
            _pendingRestartOfferSdp = sentOfferSdp;
          } finally {
            _settingDescription = false;
          }
        }
      } else {
        // Callee: process the caller's restart offer — once per unique SDP.
        final restartOfferSdp = call.restartOffer?['sdp'] as String?;
        if (restartOfferSdp != null &&
            restartOfferSdp != _lastProcessedRestartSdp) {
          _lastProcessedRestartSdp = restartOfferSdp;
          _settingDescription = true;
          try {
            await _webRtcService.setRemoteDescription(
              RTCSessionDescription(
                call.restartOffer!['sdp'] as String,
                call.restartOffer!['type'] as String,
              ),
            );
            final answer = await _webRtcService.createAnswer();
            // Re-attempt candidates buffered/failed while the restart offer
            // was being applied — new-generation candidates that arrived
            // before this setRemoteDescription failed against the old ufrag.
            await _flushPendingCandidates();
            await _retryWrite(
              operation: 'acknowledgeIceRestart',
              action: () => _callRepository.acknowledgeIceRestart(call.id, {
                'sdp': answer.sdp,
                'type': answer.type,
              }),
            );
            CallDebugLog.add(
              'ICE restart: acknowledged caller offer, buffered candidates '
              'flushed',
              name: 'Call',
            );
          } catch (e) {
            CallDebugLog.add('ICE restart: failed to process offer: $e', name: 'Call');
            // Clear so we can retry if the next update brings the same offer.
            _lastProcessedRestartSdp = null;
          } finally {
            _settingDescription = false;
          }
        }
      }
    }

    // ── Call ended / rejected / missed ────────────────────────────────────
    if (call.status == CallStatus.ended ||
        call.status == CallStatus.rejected ||
        call.status == CallStatus.missed) {
      await _cleanup();
      state = const CallState();
      return;
    }

    // ── Call connected — configure audio once ─────────────────────────────
    // Duration timer is NOT started here; it starts when the WebRTC peer
    // connection reaches Connected state so we only count media-flowing time.
    // _connectedHandled is a dedicated one-shot flag: keying off
    // _durationTimerStarted re-ran this block on every call-doc update (e.g.
    // a video toggle write) until ICE actually connected.
    if (call.status == CallStatus.connected && !_connectedHandled) {
      _connectedHandled = true;
      _ringTimeout?.cancel();
      _ringTimeout = null;
      await _callSoundService.stop();
      if (Platform.isAndroid) {
        await _callSoundService.configureForVoiceCall();
      }
      await _callKitService.setCallConnected(call.id);
    }
  }

  // ---------------------------------------------------------------------------
  // ICE candidate handling
  // ---------------------------------------------------------------------------

  void _onRemoteCandidates(List<IceCandidate> candidates) {
    for (final candidate in candidates) {
      if (!_processedCandidateIds.add(candidate.id)) continue;

      final parts = candidate.candidate.split(' ');
      final type = parts.length > 7 ? parts[7] : '?';
      CallDebugLog.add(
        'Remote candidate received: type=$type ready=$_remoteDescriptionSet '
        'candidate=${candidate.candidate}',
        name: 'Call',
      );

      final rtcCandidate = RTCIceCandidate(
        candidate.candidate,
        candidate.sdpMid,
        candidate.sdpMLineIndex,
      );

      if (_remoteDescriptionSet && !_settingDescription && !_iceRestartBuffering) {
        _addIceCandidateSafe(rtcCandidate);
      } else {
        // Buffer until remote description is ready — adding candidates before
        // setRemoteDescription (or during one, or while an ICE restart is
        // being negotiated) causes silent WebRTC failures.
        _pendingRemoteCandidates.add(rtcCandidate);
      }
    }
  }

  Future<void> _flushPendingCandidates() async {
    final toAdd = <RTCIceCandidate>[
      ..._failedRemoteCandidates,
      ..._pendingRemoteCandidates,
    ];
    _failedRemoteCandidates.clear();
    _pendingRemoteCandidates.clear();
    if (toAdd.isEmpty) return;
    CallDebugLog.add(
      'Flushing ${toAdd.length} buffered/retried remote candidates',
      name: 'Call',
    );
    for (final candidate in toAdd) {
      await _addIceCandidateSafe(candidate);
    }
  }

  Future<void> _addIceCandidateSafe(RTCIceCandidate candidate) async {
    try {
      await _webRtcService.addIceCandidate(candidate);
    } catch (e) {
      // Keep the candidate for re-attempt after the next setRemoteDescription
      // — during an ICE restart, new-generation candidates fail against the
      // old ufrag but become valid once the restart SDP is applied. The id
      // stays in _processedCandidateIds, so this list is the only retry path.
      _failedRemoteCandidates.add(candidate);
      CallDebugLog.add(
        'Failed to add ICE candidate (queued for retry): $e',
        name: 'Call',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Connection state
  // ---------------------------------------------------------------------------

  void _onConnectionState(RTCPeerConnectionState connectionState) {
    if (connectionState ==
        RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _disconnectGraceTimer?.cancel();
      _disconnectGraceTimer = null;
      _iceRestarting = false;
      // Safety net: if the connection recovered without (or despite) a
      // pending restart answer, stop buffering and drain anything queued.
      if (_iceRestartBuffering ||
          _failedRemoteCandidates.isNotEmpty ||
          _pendingRemoteCandidates.isNotEmpty) {
        _iceRestartBuffering = false;
        if (_remoteDescriptionSet) {
          unawaited(_flushPendingCandidates());
        }
      }
      state = state.copyWith(isConnecting: false);

      if (!_durationTimerStarted) {
        _durationTimerStarted = true;
        _startDurationTimer();
      }
    }

    if (connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
        connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
      // Only the original caller initiates ICE restarts (WebRTC requirement:
      // only the offerer can restart ICE).
      final call = state.activeCall;
      if (call != null && call.callerId == _currentUserId && !_iceRestarting) {
        _iceRestarting = true;
        unawaited(_attemptIceRestart(call.id));
      }

      final gracePeriod =
          connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed
          ? _failedGracePeriod
          : _disconnectGracePeriod;

      _disconnectGraceTimer?.cancel();
      _disconnectGraceTimer = Timer(gracePeriod, () {
        hangUp();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // ICE restart (caller only)
  // ---------------------------------------------------------------------------

  Future<void> _attemptIceRestart(String callId) async {
    if (_isCleaningUp) return;
    try {
      CallDebugLog.add('Attempting ICE restart for $callId', name: 'Call');
      // Buffer remote candidates until the callee's restart answer is applied
      // — the callee's new-generation candidates would otherwise be added
      // against the pre-restart ufrag and dropped.
      _iceRestartBuffering = true;
      final offer = await _webRtcService.createRestartOffer();

      // Track the SDP we sent so _onCallUpdate can match the callee's answer
      // to this specific restart attempt and not re-process it on later updates.
      _pendingRestartOfferSdp = offer.sdp;

      await _retryWrite(
        operation: 'initiateIceRestart',
        action: () => _callRepository.initiateIceRestart(callId, {
          'sdp': offer.sdp,
          'type': offer.type,
        }),
      );
    } catch (e) {
      CallDebugLog.add('ICE restart failed: $e', name: 'Call');
      _pendingRestartOfferSdp = null;
      _iceRestarting = false;
      // Restart aborted — stop buffering and add anything queued meanwhile.
      _iceRestartBuffering = false;
      if (_remoteDescriptionSet) {
        unawaited(_flushPendingCandidates());
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Local ICE candidate serialised queue
  // ---------------------------------------------------------------------------

  void _enqueueLocalCandidate(
    String callId,
    String fromUserId,
    RTCIceCandidate candidate,
  ) {
    final candidateValue = candidate.candidate;
    final sdpMid = candidate.sdpMid;
    final sdpMLineIndex = candidate.sdpMLineIndex;

    if (candidateValue == null ||
        candidateValue.isEmpty ||
        sdpMid == null ||
        sdpMLineIndex == null) {
      CallDebugLog.add('Skipping local ICE candidate with missing fields', name: 'Call');
      return;
    }

    _localCandidateQueue.add((
      callId,
      IceCandidate(
        id: _uuid.v4(),
        candidate: candidateValue,
        sdpMid: sdpMid,
        sdpMLineIndex: sdpMLineIndex,
        fromUserId: fromUserId,
        createdAt: DateTime.now(),
      ),
    ));

    _drainLocalCandidateQueue();
  }

  void _drainLocalCandidateQueue() {
    if (_processingLocalCandidates) return;
    _processingLocalCandidates = true;
    _processCandidateQueueLoop()
        .catchError((Object e) {
          CallDebugLog.add('Candidate queue error: $e', name: 'Call');
        })
        .whenComplete(() {
          _processingLocalCandidates = false;
          if (_localCandidateQueue.isNotEmpty && !_isCleaningUp) {
            _drainLocalCandidateQueue();
          }
        });
  }

  Future<void> _processCandidateQueueLoop() async {
    while (_localCandidateQueue.isNotEmpty) {
      if (_isCleaningUp) {
        _localCandidateQueue.clear();
        return;
      }
      final entry = _localCandidateQueue.removeAt(0);
      try {
        await _retryWrite(
          operation: 'addIceCandidate',
          action: () => _callRepository.addIceCandidate(entry.$1, entry.$2),
        );
      } catch (e) {
        CallDebugLog.add('ICE candidate write failed: $e', name: 'Call');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Ring timeout
  // ---------------------------------------------------------------------------

  Future<void> _onRingTimeout() async {
    if (_isCleaningUp) return;
    final call = state.activeCall;
    if (call != null && call.status == CallStatus.ringing) {
      await _retryWrite(
        operation: 'updateCall(status=missed)',
        action: () => _callRepository.updateCall(call.id, {
          'status': CallStatus.missed.name,
          'endedAt': DateTime.now().toIso8601String(),
          'endReason': CallEndReason.timeout.name,
        }),
      );
      await _cleanup();
      state = const CallState();
    }
  }

  // ---------------------------------------------------------------------------
  // Duration timer
  // ---------------------------------------------------------------------------

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        callDuration: state.callDuration + const Duration(seconds: 1),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _endCallWithError(
    String callId, {
    CallEndReason reason = CallEndReason.error,
  }) async {
    try {
      final call = await _callRepository.getCall(callId);
      if (call == null ||
          call.status == CallStatus.ended ||
          call.status == CallStatus.missed ||
          call.status == CallStatus.rejected) {
        return;
      }
      await _retryWrite(
        operation: 'updateCall(status=ended,error)',
        action: () => _callRepository.updateCall(callId, {
          'status': CallStatus.ended.name,
          'endedAt': DateTime.now().toIso8601String(),
          'endReason': reason.name,
        }),
      );
    } catch (e, st) {
      CallDebugLog.add('Failed to propagate call error for $callId: $e\n$st', name: 'Call');
    }
  }

  /// Ensures microphone permission before starting WebRTC — on iOS too:
  /// CallKit manages the audio *session*, but capture still needs the mic
  /// permission, and returning true unconditionally turned a denial into a
  /// generic "Failed to start call" later in setup.
  ///
  /// Camera is requested here (point of first potential use) rather than at
  /// video-toggle time because the video m-line must be negotiated with a
  /// real track at call setup (see WebRtcService.initialize) — a camera
  /// permission granted only mid-call could not be used until the next call.
  /// Camera denial is fine: the call proceeds audio-only.
  Future<bool> _ensureMicrophonePermission() async {
    final statuses = await [Permission.microphone, Permission.camera].request();
    return statuses[Permission.microphone]?.isGranted ?? false;
  }

  /// Fetches short-lived TURN credentials via Cloud Function.
  /// Throws [CallSetupException] if credentials cannot be obtained.
  Future<List<Map<String, dynamic>>> _fetchTurnCredentials() async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxWriteAttempts; attempt++) {
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('getTurnCredentials')
            .call();
        final data = result.data;
        final List<dynamic> servers = data is List ? data : [data];
        final parsed = servers
            .whereType<Map>()
            .map((s) => Map<String, dynamic>.from(s))
            .toList();

        if (parsed.isEmpty) throw StateError('TURN response is empty');
        CallDebugLog.add(
          'TURN credentials fetched: ${parsed.length} server(s), '
          'urls=${parsed.first['urls']}',
          name: 'Call',
        );
        return parsed;
      } catch (e) {
        lastError = e;
        CallDebugLog.add('TURN fetch attempt $attempt/$_maxWriteAttempts failed: $e', name: 'Call');
        if (attempt < _maxWriteAttempts) {
          await Future<void>.delayed(Duration(milliseconds: attempt * 500));
        }
      }
    }

    throw CallSetupException(
      'Unable to connect call: TURN credentials unavailable',
      lastError,
    );
  }

  Future<void> _retryWrite({
    required String operation,
    required Future<void> Function() action,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxWriteAttempts; attempt++) {
      try {
        await action();
        return;
      } catch (e) {
        lastError = e;
        CallDebugLog.add('$operation attempt $attempt/$_maxWriteAttempts failed: $e', name: 'Call');
        if (attempt < _maxWriteAttempts) {
          await Future<void>.delayed(Duration(milliseconds: attempt * 250));
        }
      }
    }
    throw StateError('$operation failed after retries: $lastError');
  }

  void _resetSessionState() {
    _isCleaningUp = false;
    _durationTimerStarted = false;
    _connectedHandled = false;
    _remoteDescriptionSet = false;
    _settingDescription = false;
    _iceRestarting = false;
    _iceRestartBuffering = false;
    _pendingRestartOfferSdp = null;
    _lastProcessedRestartSdp = null;
    _processedCandidateIds.clear();
    _pendingRemoteCandidates.clear();
    _failedRemoteCandidates.clear();
  }

  Future<void> _cleanup({String? callId, bool dismissCallKit = true}) async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    try {
      final activeCallId = callId ?? state.activeCall?.id;
      if (activeCallId != null && dismissCallKit) {
        await _callKitService.endCall(activeCallId);
      }

      await _callSoundService.stop();

      _ringTimeout?.cancel();
      _ringTimeout = null;
      _durationTimer?.cancel();
      _durationTimer = null;
      _disconnectGraceTimer?.cancel();
      _disconnectGraceTimer = null;

      await _callSub?.cancel();
      _callSub = null;
      await _remoteCandidateSub?.cancel();
      _remoteCandidateSub = null;
      await _localCandidateSub?.cancel();
      _localCandidateSub = null;
      await _connectionStateSub?.cancel();
      _connectionStateSub = null;
      await _remoteVideoSub?.cancel();
      _remoteVideoSub = null;

      _localCandidateQueue.clear();
      _processedCandidateIds.clear();
      _pendingRemoteCandidates.clear();
      _failedRemoteCandidates.clear();

      _remoteDescriptionSet = false;
      _settingDescription = false;
      _iceRestarting = false;
      _iceRestartBuffering = false;
      _connectedHandled = false;
      _pendingRestartOfferSdp = null;
      _lastProcessedRestartSdp = null;

      await _webRtcService.dispose();
    } finally {
      _isCleaningUp = false;
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

class CallSetupException implements Exception {
  const CallSetupException(this.message, [this.cause]);

  final String message;
  final Object? cause;
}

// ---------------------------------------------------------------------------
// Callback type
// ---------------------------------------------------------------------------

typedef VoiceNoteStopCallback = Future<void> Function();

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  final callRepository = ref.watch(firestoreCallRepositoryProvider);
  final webRtcService = ref.watch(webRtcServiceProvider);
  final callSoundService = ref.watch(callSoundServiceProvider);
  final callKitService = ref.watch(callKitServiceProvider);
  final voiceNoteService = ref.watch(voiceNoteServiceProvider);

  return CallNotifier(
    callRepository: callRepository,
    webRtcService: webRtcService,
    callSoundService: callSoundService,
    callKitService: callKitService,
    stopVoicePlayback: () => voiceNoteService.stop(),
  );
});

final incomingCallProvider = StreamProvider<Call?>((ref) {
  // Only the uid matters — don't resubscribe when transient auth flags flip.
  final userId = ref.watch(authProvider.select((state) => state.user?.uid));
  if (userId == null) return const Stream.empty();

  final callRepository = ref.watch(firestoreCallRepositoryProvider);
  return callRepository.watchIncomingCalls(userId);
});
