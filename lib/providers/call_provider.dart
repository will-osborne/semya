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

  StreamSubscription<Call?>? _callSub;
  StreamSubscription<List<IceCandidate>>? _remoteCandidateSub;
  StreamSubscription<RTCIceCandidate>? _localCandidateSub;
  StreamSubscription<RTCPeerConnectionState>? _connectionStateSub;
  StreamSubscription<bool>? _remoteVideoSub;
  StreamSubscription<Map<String, dynamic>?>? _restartNegotiationSub;
  Timer? _ringTimeout;
  Timer? _durationTimer;
  Timer? _disconnectGraceTimer;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  bool _isCleaningUp = false;
  bool _durationTimerStarted = false;
  // Guards against concurrent setRemoteDescription calls (TOCTOU fix).
  bool _remoteDescriptionSet = false;
  bool _settingRemoteDescription = false;
  // Guards against concurrent ICE restart attempts.
  bool _iceRestarting = false;
  final Set<String> _processedCandidateIds = {};
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  // Serialized queue for local ICE candidate Firestore writes.
  final List<(String, IceCandidate)> _localCandidateQueue = [];
  bool _processingLocalCandidates = false;

  static const _uuid = Uuid();
  static const _ringTimeoutDuration = Duration(seconds: 45);
  static const _disconnectGracePeriod = Duration(seconds: 20);
  static const _failedGracePeriod = Duration(seconds: 12);
  static const _offerWaitTimeout = Duration(seconds: 30);
  static const _maxWriteAttempts = 3;

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
        'Failed to propagate call failure for $callId: $e',
        name: 'CallNotifier',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Ensures microphone and camera permissions are granted before starting
  /// WebRTC. Returns true if microphone is granted (camera is optional —
  /// calls work audio-only if camera is denied).
  /// On iOS, we skip the permission_handler check because CallKit manages
  /// the audio session and getUserMedia requests permission natively.
  Future<bool> _ensureMicrophonePermission() async {
    if (Platform.isIOS) return true;
    final statuses = await [Permission.microphone, Permission.camera].request();
    // Microphone is required; camera is nice-to-have (WebRTC falls back
    // to audio-only if camera permission is denied).
    return statuses[Permission.microphone]?.isGranted ?? false;
  }

  /// Fetches short-lived TURN credentials from Cloudflare via Cloud Function.
  /// Throws if credentials cannot be fetched — TURN is mandatory for reliability.
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

        if (parsed.isEmpty) {
          throw StateError('TURN credentials response is empty');
        }
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

  /// Start an outgoing call.
  Future<void> initiateCall({
    required String calleeId,
    required String conversationId,
    required String currentUserId,
  }) async {
    // Guard: don't start a new call while one is active or connecting.
    if (state.activeCall != null || state.isConnecting) return;

    _currentUserId = currentUserId;

    // Request microphone permission before setting up WebRTC.
    if (!await _ensureMicrophonePermission()) {
      state = state.copyWith(error: 'Microphone permission required');
      return;
    }

    _isCleaningUp = false;
    _durationTimerStarted = false;
    _remoteDescriptionSet = false;
    _processedCandidateIds.clear();
    _pendingRemoteCandidates.clear();
    state = state.copyWith(isConnecting: true, clearError: true);
    String? createdCallId;

    try {
      // Stop any voice note playback.
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

      // On iOS, report the outgoing call to CallKit so it activates the
      // audio session (triggers didActivateAudioSession in AppDelegate).
      // Without this, useManualAudio keeps WebRTC audio disabled.
      if (Platform.isIOS) {
        await _callKitService.startCall(callId, calleeId);
      }

      // Fetch TURN credentials in parallel with dial tone setup.
      final turnFuture = _fetchTurnCredentials();
      _callSoundService.playDialTone(); // fire-and-forget; non-critical

      final turnCredentials = await turnFuture;

      // Initialize WebRTC with TURN credentials.
      await _webRtcService.initialize(iceServers: turnCredentials);

      // Listen for local ICE candidates BEFORE creating offer so none are
      // lost from the broadcast stream.
      _localCandidateSub = _webRtcService.localCandidates.listen((candidate) {
        _enqueueLocalCandidate(callId, currentUserId, candidate);
      });

      // Create and send offer.
      final offer = await _webRtcService.createOffer();
      await _retryWrite(
        operation: 'setOffer',
        action: () => _callRepository.setOffer(callId, {
          'sdp': offer.sdp,
          'type': offer.type,
        }),
      );

      // Watch call doc for answer / status changes.
      _callSub = _callRepository.watchCall(callId).listen(_onCallUpdate);

      // Watch remote ICE candidates from callee. Candidates that arrive
      // before the remote description is set will be buffered and flushed
      // once setRemoteDescription completes in _onCallUpdate.
      _remoteCandidateSub = _callRepository
          .watchIceCandidates(callId, calleeId)
          .listen(_onRemoteCandidates);

      // Listen for WebRTC connection state.
      _connectionStateSub = _webRtcService.connectionState.listen(
        _onConnectionState,
      );

      // Listen for remote video track changes.
      _remoteVideoSub = _webRtcService.remoteVideoStream.listen((hasVideo) {
        state = state.copyWith(hasRemoteVideo: hasVideo);
      });

      // Caller watches for ICE restart answers from the callee.
      _restartNegotiationSub = _callRepository
          .watchRestartNegotiation(callId)
          .listen((data) => _onRestartNegotiation(callId, data));

      // Start ring timeout.
      _ringTimeout = Timer(_ringTimeoutDuration, _onRingTimeout);
    } on CallSetupException catch (e, st) {
      dev.log(
        'initiateCall setup failed: ${e.message}',
        name: 'CallNotifier',
        error: e.cause,
        stackTrace: st,
      );
      final callId = createdCallId ?? state.activeCall?.id;
      if (callId != null) {
        await _endCallWithError(callId);
      }
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
      if (callId != null) {
        await _endCallWithError(callId);
      }
      await _cleanup(callId: callId);
      state = const CallState(error: 'Failed to start call');
    }
  }

  /// Answer an incoming call.
  Future<void> answerCall(String callId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    // Guard: don't answer while already in a call or already connecting.
    // This prevents a race condition where both _handleAcceptedCall and
    // CallScreen.build trigger concurrent joinCall → answerCall calls.
    if (state.activeCall != null || state.isConnecting) return;

    // Request microphone permission before setting up WebRTC.
    if (!await _ensureMicrophonePermission()) {
      await _endCallWithError(callId);
      await _cleanup(callId: callId);
      state = state.copyWith(error: 'Microphone permission required');
      return;
    }

    _isCleaningUp = false;
    _durationTimerStarted = false;
    _remoteDescriptionSet = false;
    _processedCandidateIds.clear();
    _pendingRemoteCandidates.clear();
    state = state.copyWith(isConnecting: true, clearError: true);

    try {
      // Stop any voice note playback.
      await _stopVoicePlayback();

      // Kick off TURN credentials fetch and audio config in parallel.
      final turnFuture = _fetchTurnCredentials();
      if (Platform.isAndroid) {
        _callSoundService.configureForVoiceCall(); // fire-and-forget
      }

      final turnCredentials = await turnFuture;

      // Initialize WebRTC with TURN credentials.
      await _webRtcService.initialize(iceServers: turnCredentials);

      // Listen for local ICE candidates BEFORE creating answer so none are
      // lost from the broadcast stream.
      _localCandidateSub = _webRtcService.localCandidates.listen((candidate) {
        _enqueueLocalCandidate(callId, uid, candidate);
      });

      // Watch the call doc to get the offer, with a timeout.
      final callStream = _callRepository.watchCall(callId);
      final call = await callStream
          .where((c) => c != null && c.offer != null)
          .first
          .timeout(_offerWaitTimeout);

      if (call == null || call.offer == null) {
        await _endCallWithError(callId);
        await _cleanup(callId: callId);
        state = const CallState(error: 'Call not found');
        return;
      }

      // Verify the call is still ringing before proceeding.
      if (call.status != CallStatus.ringing) {
        await _cleanup(callId: callId);
        state = const CallState(error: 'Call no longer available');
        return;
      }

      state = state.copyWith(activeCall: call);

      // Set remote description (the offer).
      await _webRtcService.setRemoteDescription(
        RTCSessionDescription(
          call.offer!['sdp'] as String,
          call.offer!['type'] as String,
        ),
      );
      _remoteDescriptionSet = true;
      await _flushPendingCandidates();

      // Subscribe to all streams BEFORE writing to Firestore so that any
      // status change from the caller (e.g. hangup) arriving during the
      // async writes below is not missed (Issue 8 fix).
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
      // Callee watches for ICE restart offers from the caller.
      _restartNegotiationSub = _callRepository
          .watchRestartNegotiation(callId)
          .listen((data) => _onRestartNegotiation(callId, data));

      // Create and send answer.
      final answer = await _webRtcService.createAnswer();
      await _retryWrite(
        operation: 'setAnswer',
        action: () => _callRepository.setAnswer(callId, {
          'sdp': answer.sdp,
          'type': answer.type,
        }),
      );

      // Update status to connected (signals to the caller that we answered).
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

  /// Loads an existing call into state (e.g. when navigating from a notification).
  /// If the call is still ringing, it answers it. If already connected, it
  /// joins the existing session.
  Future<void> joinCall(String callId) async {
    // Already tracking this call.
    if (state.activeCall?.id == callId) return;

    // Guard: don't join while already connecting another call.
    if (state.isConnecting) return;

    final uid = _currentUserId;
    if (uid == null) return;

    final call = await _callRepository.getCall(callId);
    if (call == null) {
      state = state.copyWith(error: 'Call not found');
      return;
    }

    // Call already ended.
    if (call.status == CallStatus.ended ||
        call.status == CallStatus.missed ||
        call.status == CallStatus.rejected) {
      state = state.copyWith(error: 'Call already ended');
      return;
    }

    // If we're the callee and the call is still ringing, answer it. Calls that
    // are already connected should be observed, not re-answered, otherwise we
    // can overwrite signaling state and desynchronize the caller.
    if (call.calleeId == uid && call.status == CallStatus.ringing) {
      await answerCall(callId);
      return;
    }

    // Otherwise just set it as active and watch for updates.
    state = state.copyWith(activeCall: call);
    _callSub = _callRepository.watchCall(callId).listen(_onCallUpdate);
  }

  /// Reject an incoming call.
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
      // Cancel Firestore listener first to avoid double-cleanup from
      // _onCallUpdate seeing the status change we're about to write.
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

    // Signal video state to the remote peer via Firestore.
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

  /// Set the current user ID (called when the provider is first read).
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  Future<void> _onCallUpdate(Call? call) async {
    if (call == null || _isCleaningUp) return;

    // Determine if the remote peer has video enabled.
    final isCaller = call.callerId == _currentUserId;
    final remoteVideoEnabled = isCaller
        ? call.calleeVideoEnabled
        : call.callerVideoEnabled;

    state = state.copyWith(
      activeCall: call,
      hasRemoteVideo: remoteVideoEnabled,
    );

    // Guard against concurrent setRemoteDescription calls: check AND set
    // the in-progress flag synchronously before any await (Issue 1 fix).
    if (call.answer != null &&
        call.callerId == _currentUserId &&
        !_remoteDescriptionSet &&
        !_settingRemoteDescription) {
      _settingRemoteDescription = true;
      try {
        await _webRtcService.setRemoteDescription(
          RTCSessionDescription(
            call.answer!['sdp'] as String,
            call.answer!['type'] as String,
          ),
        );
        _remoteDescriptionSet = true;
        await _flushPendingCandidates();
      } finally {
        _settingRemoteDescription = false;
      }
    }

    // If the call is connected (callee answered), configure audio/CallKit once.
    // The duration timer is NOT started here — it starts when the WebRTC
    // peer connection actually reaches Connected state, ensuring we only
    // count time when media is flowing (Issue 5 fix).
    if (call.status == CallStatus.connected && !_durationTimerStarted) {
      _ringTimeout?.cancel();
      await _callSoundService.stop();

      // On Android, reconfigure audio session for voice call.
      // On iOS, CallKit manages the audio session.
      if (Platform.isAndroid) {
        await _callSoundService.configureForVoiceCall();
      }

      await _callKitService.setCallConnected(call.id);
    }

    // Call ended/rejected/missed by the other party.
    if (call.status == CallStatus.ended ||
        call.status == CallStatus.rejected ||
        call.status == CallStatus.missed) {
      await _cleanup();
      state = const CallState();
    }
  }

  void _onRemoteCandidates(List<IceCandidate> candidates) {
    for (final candidate in candidates) {
      // Skip already-processed candidates.
      if (!_processedCandidateIds.add(candidate.id)) continue;

      final rtcCandidate = RTCIceCandidate(
        candidate.candidate,
        candidate.sdpMid,
        candidate.sdpMLineIndex,
      );

      if (_remoteDescriptionSet) {
        _addIceCandidateSafe(rtcCandidate);
      } else {
        // Buffer until remote description is set — adding candidates
        // before setRemoteDescription causes silent WebRTC failures.
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

  void _onConnectionState(RTCPeerConnectionState connectionState) {
    if (connectionState ==
        RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _disconnectGraceTimer?.cancel();
      _disconnectGraceTimer = null;
      _iceRestarting = false;
      state = state.copyWith(isConnecting: false);

      // Start duration timer only once media is actually flowing (Issue 5 fix).
      if (!_durationTimerStarted) {
        _durationTimerStarted = true;
        _startDurationTimer();
      }
    }

    if (connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
        connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
      // Attempt ICE restart if we are the original caller and not already
      // restarting. ICE restart re-gathers candidates over the new network
      // path without tearing down the call (Issue 3 fix).
      final call = state.activeCall;
      if (call != null && call.callerId == _currentUserId && !_iceRestarting) {
        _iceRestarting = true;
        unawaited(_attemptIceRestart(call.id));
      }

      // Grace timer: hang up if the connection doesn't recover in time.
      _disconnectGraceTimer?.cancel();
      final gracePeriod =
          connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed
          ? _failedGracePeriod
          : _disconnectGracePeriod;
      _disconnectGraceTimer = Timer(gracePeriod, () {
        hangUp();
      });
    }
  }

  /// Initiates ICE restart as the caller: creates a new offer with
  /// iceRestart=true, writes it to Firestore, and waits for the callee's
  /// restart answer via [_onRestartNegotiation].
  Future<void> _attemptIceRestart(String callId) async {
    if (_isCleaningUp) return;
    try {
      dev.log('Attempting ICE restart for call $callId', name: 'CallNotifier');
      final offer = await _webRtcService.createRestartOffer();
      await _retryWrite(
        operation: 'setRestartOffer',
        action: () => _callRepository.setRestartOffer(callId, {
          'sdp': offer.sdp,
          'type': offer.type,
        }),
      );
    } catch (e) {
      dev.log('ICE restart offer failed: $e', name: 'CallNotifier');
      _iceRestarting = false;
    }
  }

  /// Handles incoming restart negotiation updates from Firestore.
  ///
  /// - As the callee: when a restart offer arrives, creates and writes a
  ///   restart answer.
  /// - As the caller: when a restart answer arrives (after writing the offer),
  ///   sets it as the remote description to complete the restart.
  Future<void> _onRestartNegotiation(
    String callId,
    Map<String, dynamic>? data,
  ) async {
    if (data == null || _isCleaningUp) return;
    final offer = data['offer'] as Map<String, dynamic>?;
    final answer = data['answer'] as Map<String, dynamic>?;
    if (offer == null) return;

    final isCaller = state.activeCall?.callerId == _currentUserId;

    if (isCaller) {
      // Caller: set the callee's restart answer as remote description.
      if (answer == null || _settingRemoteDescription) return;
      _settingRemoteDescription = true;
      try {
        await _webRtcService.setRemoteDescription(
          RTCSessionDescription(
            answer['sdp'] as String,
            answer['type'] as String,
          ),
        );
        dev.log('ICE restart: set restart answer', name: 'CallNotifier');
      } catch (e) {
        dev.log('ICE restart: failed to set answer: $e', name: 'CallNotifier');
      } finally {
        _settingRemoteDescription = false;
      }
    } else {
      // Callee: respond to the caller's restart offer with a new answer.
      if (_settingRemoteDescription) return;
      _settingRemoteDescription = true;
      try {
        await _webRtcService.setRemoteDescription(
          RTCSessionDescription(
            offer['sdp'] as String,
            offer['type'] as String,
          ),
        );
        final restartAnswer = await _webRtcService.createAnswer();
        await _retryWrite(
          operation: 'setRestartAnswer',
          action: () => _callRepository.setRestartAnswer(callId, {
            'sdp': restartAnswer.sdp,
            'type': restartAnswer.type,
          }),
        );
        dev.log('ICE restart: sent restart answer', name: 'CallNotifier');
      } catch (e) {
        dev.log('ICE restart: failed to send answer: $e', name: 'CallNotifier');
      } finally {
        _settingRemoteDescription = false;
      }
    }
  }

  void _onRingTimeout() async {
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
  // Local ICE candidate queue (Issue 2 fix)
  // ---------------------------------------------------------------------------

  /// Enqueues a local ICE candidate for serialized Firestore writing.
  /// The listener callback is kept synchronous; writing is done by the drain.
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
    final iceCandidate = IceCandidate(
      id: _uuid.v4(),
      candidate: candidateValue,
      sdpMid: sdpMid,
      sdpMLineIndex: sdpMLineIndex,
      fromUserId: fromUserId,
      createdAt: DateTime.now(),
    );
    _localCandidateQueue.add((callId, iceCandidate));
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
          // Re-drain if items were added while the loop was running.
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

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        callDuration: state.callDuration + const Duration(seconds: 1),
      );
    });
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
      await _restartNegotiationSub?.cancel();
      _restartNegotiationSub = null;
      _localCandidateQueue.clear();
      _processedCandidateIds.clear();
      _pendingRemoteCandidates.clear();
      _remoteDescriptionSet = false;
      _settingRemoteDescription = false;
      _iceRestarting = false;
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

class CallSetupException implements Exception {
  const CallSetupException(this.message, [this.cause]);

  final String message;
  final Object? cause;
}

// ---------------------------------------------------------------------------
// Callback type for stopping voice playback
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
