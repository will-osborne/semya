import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:semya/data/services/call_debug_log.dart';

class WebRtcService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = false;
  bool _isFrontCamera = true;
  bool _renderersInitialized = false;

  // The RTP sender carrying the video m-line, captured at initialize().
  // Video is (re)enabled by swapping fresh camera tracks onto this sender
  // via replaceTrack — no SDP renegotiation needed. Null when the session
  // was set up audio-only (camera unavailable/denied at call start).
  RTCRtpSender? _videoSender;

  // Controllers are recreated each call via initialize() / dispose().
  StreamController<RTCIceCandidate>? _localCandidateController;
  StreamController<RTCPeerConnectionState>? _connectionStateController;

  // Audio route change listener (headphones, Bluetooth, etc.).
  StreamSubscription<AudioDevicesChangedEvent>? _audioRouteChangeSub;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // Notifies UI when remote video track arrives or is removed.
  final StreamController<bool> _remoteVideoController =
      StreamController<bool>.broadcast();
  Stream<bool> get remoteVideoStream => _remoteVideoController.stream;
  bool _hasRemoteVideo = false;
  bool get hasRemoteVideo => _hasRemoteVideo;

  Stream<RTCIceCandidate> get localCandidates =>
      _localCandidateController!.stream;
  Stream<RTCPeerConnectionState> get connectionState =>
      _connectionStateController!.stream;

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoEnabled => _isVideoEnabled;

  // Deduplication: only emit a connection state change when it differs from
  // the last value. Both onConnectionState and onIceConnectionState map to
  // the same stream; without this they would fire duplicate events.
  RTCPeerConnectionState? _lastEmittedConnectionState;

  void _emitConnectionState(RTCPeerConnectionState state) {
    if (state == _lastEmittedConnectionState) return;
    _lastEmittedConnectionState = state;
    final controller = _connectionStateController;
    if (controller != null && !controller.isClosed) {
      controller.add(state);
    }
  }

  /// Pass [iceServers] from Cloudflare TURN credentials.
  ///
  /// [captureVideo] controls whether a camera track is acquired and added at
  /// setup. Pass false when camera permission isn't granted — the session is
  /// then audio-only for its whole lifetime (the video m-line is only
  /// negotiated at setup; see the comment above getUserMedia below).
  Future<void> initialize({
    required List<Map<String, dynamic>> iceServers,
    bool captureVideo = true,
  }) async {
    // Create fresh controllers for each call session.
    _localCandidateController = StreamController<RTCIceCandidate>.broadcast();
    _connectionStateController =
        StreamController<RTCPeerConnectionState>.broadcast();

    // Always initialize renderers so onTrack can assign remote streams.
    if (!_renderersInitialized) {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersInitialized = true;
    }

    // Detect when the first remote video frame actually renders.
    remoteRenderer.onFirstFrameRendered = () {
      if (!_hasRemoteVideo) {
        _hasRemoteVideo = true;
        if (!_remoteVideoController.isClosed) {
          _remoteVideoController.add(true);
        }
      }
    };

    final configuration = {
      'iceServers': iceServers,
      // Explicit SDP semantics avoids platform-dependent defaults.
      'sdpSemantics': 'unified-plan',
      // All media (audio + video) shares one ICE transport — halves the
      // number of candidates that must be exchanged.
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    CallDebugLog.add('createPeerConnection starting', name: 'WebRTC');
    _peerConnection = await createPeerConnection(configuration);
    CallDebugLog.add('createPeerConnection done', name: 'WebRTC');

    _peerConnection!.onIceCandidate = (candidate) {
      CallDebugLog.add(
        'ICE candidate: type=${candidate.candidate?.split(' ').elementAtOrNull(7) ?? '?'} '
        'candidate=${candidate.candidate}',
        name: 'WebRTC',
      );
      final controller = _localCandidateController;
      if (controller != null && !controller.isClosed) {
        controller.add(candidate);
      }
    };

    // onConnectionState is the primary state signal. On some iOS builds of
    // flutter_webrtc it fires inconsistently, so onIceConnectionState acts
    // as a complementary source. _emitConnectionState deduplicates.
    _peerConnection!.onConnectionState = (state) {
      CallDebugLog.add('Connection state: $state', name: 'WebRTC');
      _emitConnectionState(state);
    };

    _peerConnection!.onIceConnectionState = (iceState) {
      CallDebugLog.add('ICE connection state: $iceState', name: 'WebRTC');
      switch (iceState) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _emitConnectionState(
            RTCPeerConnectionState.RTCPeerConnectionStateConnected,
          );
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _emitConnectionState(
            RTCPeerConnectionState.RTCPeerConnectionStateFailed,
          );
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _emitConnectionState(
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
          );
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _emitConnectionState(
            RTCPeerConnectionState.RTCPeerConnectionStateClosed,
          );
        default:
          break;
      }
    };

    // Handle remote tracks (audio + video).
    _peerConnection!.onTrack = (event) {
      CallDebugLog.add(
        'onTrack: kind=${event.track.kind}, streams=${event.streams.length}',
        name: 'WebRTC',
      );
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
      }
    };

    // Fallback for platforms where onTrack doesn't deliver streams.
    _peerConnection!.onAddStream = (stream) {
      CallDebugLog.add(
        'onAddStream: audio=${stream.getAudioTracks().length}, '
        'video=${stream.getVideoTracks().length}',
        name: 'WebRTC',
      );
      _remoteStream = stream;
      remoteRenderer.srcObject = stream;
    };

    // Acquire audio + video. The video track is added at setup so the video
    // m-line is negotiated with a REAL track — onTrack fires on the remote
    // side for both kinds, avoiding iOS bugs with replaceTrack(null →
    // realTrack) and addTransceiver. Full mid-call renegotiation is not an
    // option in this architecture: only the original caller can push offers
    // through the restartOffer machinery, so a callee could never add a
    // video m-line later. The camera track is therefore acquired up front
    // and then STOPPED (below) — the m-line survives, but the camera
    // indicator turns off and no battery is drained while video is off.
    if (captureVideo) {
      CallDebugLog.add('getUserMedia(audio+video) starting', name: 'WebRTC');
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 640},
            'height': {'ideal': 480},
          },
        });
        CallDebugLog.add('getUserMedia(audio+video) done', name: 'WebRTC');
        // Disable video track immediately — no video sent until toggled on.
        for (final track in _localStream!.getVideoTracks()) {
          track.enabled = false;
        }
      } catch (e) {
        // Camera unavailable (e.g. hardware issue, simulator).
        // Fall back to audio-only.
        CallDebugLog.add(
          'Camera unavailable, falling back to audio-only: $e',
          name: 'WebRTC',
        );
        _localStream = null;
      }
    }

    if (_localStream == null) {
      CallDebugLog.add('getUserMedia(audio-only) starting', name: 'WebRTC');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      CallDebugLog.add('getUserMedia(audio-only) done', name: 'WebRTC');
    }

    // Add all tracks to the peer connection, remembering the video sender so
    // toggleVideo can replaceTrack onto it later.
    CallDebugLog.add('addTrack starting', name: 'WebRTC');
    for (final track in _localStream!.getTracks()) {
      final sender = await _peerConnection!.addTrack(track, _localStream!);
      if (track.kind == 'video') {
        _videoSender = sender;
      }
    }
    CallDebugLog.add('addTrack done', name: 'WebRTC');

    // Release the camera while video is off. A merely-disabled track keeps
    // the camera capturing (indicator on, battery drain); stopping it does
    // not remove the negotiated m-line — the sender stays in place and the
    // next toggleVideo swaps a fresh camera track onto it.
    for (final track in _localStream!.getVideoTracks()) {
      await track.stop();
    }

    // Default to earpiece (not loudspeaker).
    // On iOS, CallKit manages audio routing — calling setSpeakerphoneOn
    // interferes with the CallKit-managed audio session.
    _isSpeakerOn = false;
    if (!Platform.isIOS) {
      CallDebugLog.add('setSpeakerphoneOn(false) starting', name: 'WebRTC');
      Helper.setSpeakerphoneOn(false);
      CallDebugLog.add('setSpeakerphoneOn(false) done', name: 'WebRTC');
    }

    // Listen for audio route changes (headphone connect/disconnect, Bluetooth
    // switch) and re-apply the routing preference so the system doesn't
    // silently reroute audio to an unexpected device (Issue 10 fix).
    CallDebugLog.add('AudioSession.instance starting', name: 'WebRTC');
    final session = await AudioSession.instance;
    // Configure audio session for voice calls — activates hardware AEC on iOS
    // (voiceChat mode) and voice communication routing on Android. Without this
    // the session remains in default mode with no echo cancellation.
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
          AVAudioSessionCategoryOptions.allowBluetoothA2dp,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ));
    CallDebugLog.add('AudioSession.instance done', name: 'WebRTC');
    _audioRouteChangeSub = session.devicesChangedEventStream.listen((_) {
      if (!Platform.isIOS) {
        Helper.setSpeakerphoneOn(_isSpeakerOn);
      }
    });
    CallDebugLog.add('WebRtcService.initialize() complete', name: 'WebRTC');
  }

  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  /// Creates a new offer with ICE restart enabled. Used to recover a
  /// disconnected call without tearing down and rebuilding the peer connection.
  Future<RTCSessionDescription> createRestartOffer() async {
    final offer = await _peerConnection!.createOffer({'iceRestart': true});
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    final audioTracks = _localStream?.getAudioTracks();
    if (audioTracks != null) {
      for (final track in audioTracks) {
        track.enabled = !_isMuted;
      }
    }
  }

  Future<void> toggleSpeaker() async {
    final newValue = !_isSpeakerOn;
    if (Platform.isIOS) {
      // On iOS, use AVAudioSession.overrideOutputAudioPort — works alongside
      // CallKit without conflicting with its audio session ownership.
      final avSession = AVAudioSession();
      await avSession.overrideOutputAudioPort(
        newValue
            ? AVAudioSessionPortOverride.speaker
            : AVAudioSessionPortOverride.none,
      );
    } else {
      Helper.setSpeakerphoneOn(newValue);
    }
    _isSpeakerOn = newValue;
  }

  /// Toggles local video. The video m-line was negotiated at initialize()
  /// with a real (since stopped) track, so enabling acquires a fresh camera
  /// track and swaps it onto the existing sender via replaceTrack — no SDP
  /// renegotiation. Disabling stops the track outright so the camera
  /// indicator turns off and no battery is drained.
  Future<bool> toggleVideo() async {
    if (!_isVideoEnabled) {
      final started = await _startVideoCapture();
      if (!started) return false;
      localRenderer.srcObject = _localStream;
      _isVideoEnabled = true;

      // Switch to speaker for video calls.
      if (!_isSpeakerOn) {
        await toggleSpeaker();
      }
      return true;
    } else {
      await _stopVideoCapture();
      localRenderer.srcObject = null;
      _isVideoEnabled = false;
      return true;
    }
  }

  /// Acquires a fresh camera track and swaps it onto the video sender that
  /// was negotiated at call setup. replaceTrack(track → track) requires no
  /// renegotiation because the m-line already exists.
  Future<bool> _startVideoCapture() async {
    final sender = _videoSender;
    // Audio-only session (camera denied/unavailable at setup) — no video
    // m-line was negotiated, so video cannot be enabled for this call.
    if (sender == null) return false;

    try {
      CallDebugLog.add('getUserMedia(video) for enable starting', name: 'WebRTC');
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': _isFrontCamera ? 'user' : 'environment',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      });
      final newTrack = stream.getVideoTracks().first;
      await sender.replaceTrack(newTrack);

      // Keep _localStream consistent for the renderer and dispose().
      final local = _localStream;
      if (local != null) {
        for (final old in local.getVideoTracks()) {
          await local.removeTrack(old);
          await old.stop();
        }
        await local.addTrack(newTrack);
      }
      CallDebugLog.add('Video capture started (replaceTrack)', name: 'WebRTC');
      return true;
    } catch (e) {
      CallDebugLog.add('Failed to start video capture: $e', name: 'WebRTC');
      return false;
    }
  }

  /// Stops (not just disables) the local camera track. The stopped track
  /// stays attached to the sender, keeping the m-line valid; the next enable
  /// replaces it with a fresh one.
  Future<void> _stopVideoCapture() async {
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    for (final track in tracks) {
      track.enabled = false;
      await track.stop();
    }
  }

  Future<void> switchCamera() async {
    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
      _isFrontCamera = !_isFrontCamera;
    }
  }

  /// Releases resources for the current call. Safe to call multiple times.
  /// The service can be reused by calling initialize() again.
  Future<void> dispose() async {
    await _audioRouteChangeSub?.cancel();
    _audioRouteChangeSub = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;

    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    _isMuted = false;
    _isSpeakerOn = false;
    _isVideoEnabled = false;
    _isFrontCamera = true;
    _hasRemoteVideo = false;
    _videoSender = null;
    _lastEmittedConnectionState = null;

    if (_renderersInitialized) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      remoteRenderer.onFirstFrameRendered = null;
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      localRenderer = RTCVideoRenderer();
      remoteRenderer = RTCVideoRenderer();
      _renderersInitialized = false;
    }

    await _localCandidateController?.close();
    _localCandidateController = null;
    await _connectionStateController?.close();
    _connectionStateController = null;
  }
}
