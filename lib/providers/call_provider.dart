import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

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

  // Guards concurrent setRemoteDescription calls from overlapping stream events.
  bool _settingDescription = false;

  // Initial handshake: true once the caller has applied the callee's answer.
  bool _remoteDescriptionSet = false;

  // ── ICE candidate management ──────────────────────────────────────────────
  final Set<String> _processedCandidateIds = {};

  // Remote candidates buffered while setRemoteDescription hasn't completed yet.
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

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

    if (!await _ensureMicrophonePermission()) {
      state = state.copyWith(error: 'Microphone permission required');
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
      await _webRtcService.initialize(iceServers: turnCredentials);

      // Subscribe to local ICE candidates BEFORE creating the offer so no
      // candidates are lost from the broadcast stream.
      _localCandidateSub = _webRtcService.localCandidates.listen((candidate) {
        _enqueueLocalCandidate(callId, currentUserId, candidate);
      });

      final offer = await _webRtcService.createOffer();
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
      dev.log(
        'initiateCall setup failed: ${e.message}',
        name: 'CallNotifier',
        error: e.cause,
        stackTrace: st,
      );
      final callId = createdCallId ?? state.activeCall?.id;
      if (callId != null) await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = CallState(error: e.message);
    } catch (e, st) {
      dev.log(
        'initiateCall failed: $e',
        name: 'CallNotifier',
        error: e,
        stackTrace: st,
      );
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
      state = state.copyWith(error: 'Microphone permission required');
      return;
    }

    _resetSessionState();
    state = state.copyWith(isConnecting: true, clearError: true);

    try {
      await _stopVoicePlayback();

      final turnFuture = _fetchTurnCredentials();
      if (Platform.isAndroid) {
        _callSoundService.configureForVoiceCall();
      }

      final turnCredentials = await turnFuture;
      await _webRtcService.initialize(iceServers: turnCredentials);

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
      dev.log('answerCall timed out waiting for offer', name: 'CallNotifier');
      await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = const CallState(error: 'Call timed out');
    } on CallSetupException catch (e, st) {
      dev.log(
        'answerCall setup failed: ${e.message}',
        name: 'CallNotifier',
        error: e.cause,
        stackTrace: st,
      );
      await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = CallState(error: e.message);
    } catch (e, st) {
      dev.log(
        'answerCall failed: $e',
        name: 'CallNotifier',
        error: e,
        stackTrace: st,
      );
      await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = const CallState(error: 'Failed to answer call');
    }
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

  void toggleSpeaker() {
    _webRtcService.toggleSpeaker();
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
        dev.log(
          'Failed to apply callee answer: $e',
          name: 'CallNotifier',
        );
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
            await _flushPendingCandidates();
            dev.log('ICE restart: applied callee answer', name: 'CallNotifier');
          } catch (e) {
            dev.log(
              'ICE restart: failed to apply answer: $e',
              name: 'CallNotifier',
            );
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
            await _retryWrite(
              operation: 'acknowledgeIceRestart',
              action: () => _callRepository.acknowledgeIceRestart(call.id, {
                'sdp': answer.sdp,
                'type': answer.type,
              }),
            );
            dev.log(
              'ICE restart: acknowledged caller offer',
              name: 'CallNotifier',
            );
          } catch (e) {
            dev.log(
              'ICE restart: failed to process offer: $e',
              name: 'CallNotifier',
            );
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
    if (call.status == CallStatus.connected && !_durationTimerStarted) {
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

      final rtcCandidate = RTCIceCandidate(
        candidate.candidate,
        candidate.sdpMid,
        candidate.sdpMLineIndex,
      );

      if (_remoteDescriptionSet) {
        _addIceCandidateSafe(rtcCandidate);
      } else {
        // Buffer until remote description is ready — adding candidates before
        // setRemoteDescription causes silent WebRTC failures.
        _pendingRemoteCandidates.add(rtcCandidate);
      }
    }
  }

  Future<void> _flushPendingCandidates() async {
    for (final candidate in _pendingRemoteCandidates) {
      await _addIceCandidateSafe(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  Future<void> _addIceCandidateSafe(RTCIceCandidate candidate) async {
    try {
      await _webRtcService.addIceCandidate(candidate);
    } catch (e) {
      dev.log('Failed to add ICE candidate: $e', name: 'CallNotifier');
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
      dev.log('Attempting ICE restart for $callId', name: 'CallNotifier');
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
      dev.log('ICE restart failed: $e', name: 'CallNotifier');
      _pendingRestartOfferSdp = null;
      _iceRestarting = false;
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
      dev.log(
        'Skipping local ICE candidate with missing fields',
        name: 'CallNotifier',
      );
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
          dev.log('Candidate queue error: $e', name: 'CallNotifier');
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
        dev.log('ICE candidate write failed: $e', name: 'CallNotifier');
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
      dev.log(
        'Failed to propagate call error for $callId: $e',
        name: 'CallNotifier',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Ensures microphone permission before starting WebRTC. Camera is optional.
  /// On iOS, CallKit manages the audio session so we skip the permission check.
  Future<bool> _ensureMicrophonePermission() async {
    if (Platform.isIOS) return true;
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
        return parsed;
      } catch (e) {
        lastError = e;
        dev.log(
          'TURN fetch attempt $attempt/$_maxWriteAttempts failed: $e',
          name: 'CallNotifier',
        );
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
        dev.log(
          '$operation attempt $attempt/$_maxWriteAttempts failed: $e',
          name: 'CallNotifier',
        );
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
    _remoteDescriptionSet = false;
    _settingDescription = false;
    _iceRestarting = false;
    _pendingRestartOfferSdp = null;
    _lastProcessedRestartSdp = null;
    _processedCandidateIds.clear();
    _pendingRemoteCandidates.clear();
  }

  Future<void> _cleanup({String? callId}) async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    try {
      final activeCallId = callId ?? state.activeCall?.id;
      if (activeCallId != null) {
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

      _remoteDescriptionSet = false;
      _settingDescription = false;
      _iceRestarting = false;
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
  final authState = ref.watch(authProvider);
  final userId = authState.user?.uid;
  if (userId == null) return const Stream.empty();

  final callRepository = ref.watch(firestoreCallRepositoryProvider);
  return callRepository.watchIncomingCalls(userId);
});
