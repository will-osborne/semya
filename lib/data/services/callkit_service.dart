import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

typedef CallKitCallback = void Function(String callId);
typedef VoipTokenCallback = void Function(String token);

class CallKitService {
  StreamSubscription<CallEvent?>? _eventSub;

  CallKitCallback? onCallAccepted;
  CallKitCallback? onCallDeclined;
  CallKitCallback? onCallEnded;
  CallKitCallback? onCallTimeout;
  VoipTokenCallback? onVoipTokenUpdated;

  /// Shows the native incoming call UI.
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      type: 0, // Audio call
      duration: 45000, // 45 seconds
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
      ),
      ios: const IOSParams(
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.020,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: null, // Uses system default
      ),
      android: const AndroidParams(
        isShowFullLockedScreen: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#1C1C1E',
        actionColor: '#4CAF50',
        textColor: '#FFFFFF',
        isShowCallID: false,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
    dev.log('Showed incoming call UI for $callId', name: 'CallKitService');
  }

  /// Reports an outgoing call to CallKit so it activates the audio session.
  /// On iOS this is essential — without it `didActivateAudioSession` never
  /// fires and WebRTC audio stays disabled (useManualAudio = true).
  Future<void> startCall(String callId, String calleeName) async {
    try {
      final params = CallKitParams(
        id: callId,
        nameCaller: calleeName,
        type: 0,
        ios: const IOSParams(
          audioSessionMode: 'voiceChat',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.020,
        ),
        android: const AndroidParams(
          isShowFullLockedScreen: false,
          isShowLogo: false,
        ),
      );
      await FlutterCallkitIncoming.startCall(params);
      dev.log('Started outgoing call for $callId', name: 'CallKitService');
    } catch (e) {
      dev.log('startCall failed (non-fatal): $e', name: 'CallKitService');
    }
  }

  /// Dismisses the native call UI.
  Future<void> endCall(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId);
      dev.log('Ended call UI for $callId', name: 'CallKitService');
    } catch (e) {
      dev.log('endCall failed (non-fatal): $e', name: 'CallKitService');
    }
  }

  /// Marks the call as connected (updates the native UI state).
  Future<void> setCallConnected(String callId) async {
    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
      dev.log('Set call connected for $callId', name: 'CallKitService');
    } catch (e) {
      dev.log('setCallConnected failed (non-fatal): $e', name: 'CallKitService');
    }
  }

  /// Returns the current VoIP push token (iOS only, null on Android).
  Future<String?> getVoipToken() async {
    return await FlutterCallkitIncoming.getDevicePushTokenVoIP();
  }

  Future<List<Map<String, dynamic>>> getActiveCalls() async {
    final activeCalls = await FlutterCallkitIncoming.activeCalls();
    if (activeCalls is! List) return const [];

    return activeCalls
        .whereType<Map>()
        .map((call) => Map<String, dynamic>.from(call))
        .toList();
  }

  /// Subscribes to CallKit events and dispatches to callbacks.
  void startListening() {
    _eventSub?.cancel();
    _eventSub = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;

      final body = event.body as Map<String, dynamic>? ?? {};
      final callId = body['id'] as String? ?? '';
      dev.log(
        'CallKit event: ${event.event}, callId=$callId',
        name: 'CallKitService',
      );

      switch (event.event) {
        case Event.actionCallAccept:
          onCallAccepted?.call(callId);
        case Event.actionCallDecline:
          onCallDeclined?.call(callId);
        case Event.actionCallEnded:
          onCallEnded?.call(callId);
        case Event.actionCallTimeout:
          onCallTimeout?.call(callId);
        case Event.actionDidUpdateDevicePushTokenVoip:
          final token = body['devicePushTokenVoIP'] as String?;
          if (token != null && token.isNotEmpty) {
            dev.log(
              'VoIP token updated: ${token.substring(0, 8)}...',
              name: 'CallKitService',
            );
            onVoipTokenUpdated?.call(token);
          }
        default:
          break;
      }
    });
  }

  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
  }
}
