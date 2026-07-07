import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'app.dart';
import 'data/services/call_debug_log.dart';
import 'firebase_options.dart';
import 'providers/locale_provider.dart';

/// Top-level background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Show the native incoming call UI for call-type data messages.
  if (message.data['type'] == 'call') {
    // iOS receives incoming calls via PushKit VoIP push, which shows CallKit
    // natively in AppDelegate. This FCM data push is also delivered to iOS,
    // so showing CallKit here again would produce a double ring.
    if (!Platform.isAndroid) return;

    final callId = message.data['callId'] as String? ?? '';
    final callerName = message.data['callerName'] as String? ?? 'Unknown';

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      type: 0,
      duration: 45000,
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
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
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

    // The main isolate may not be running (app terminated). Keep this
    // background isolate alive briefly so a decline still reaches Firestore
    // and the caller's phone stops ringing.
    await _propagateBackgroundDecline(callId);
  } else if (message.data['type'] == 'call_cancelled') {
    // Caller hung up / call timed out while we were ringing in the
    // background — dismiss the native incoming-call UI. Ending an unknown
    // or already-dismissed call id is a no-op.
    final callId = message.data['callId'] as String? ?? '';
    if (callId.isNotEmpty) {
      CallDebugLog.add(
        'Background cancel push received for $callId',
        name: 'Call',
      );
      await FlutterCallkitIncoming.endCall(callId);
    }
  } else if (message.data['type'] == 'message' &&
      message.notification == null) {
    // Data-only message push (server sets content_available=true without a
    // notification key). iOS delivers these silently in background; show a
    // local notification so the user actually sees it.
    final conversationId = message.data['conversationId'] as String? ?? '';
    if (conversationId.isEmpty) return;

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    final title = message.data['senderName'] as String? ?? 'New message';
    final String body;
    switch (message.data['messageType'] as String?) {
      case 'image':
        body = 'Photo';
      case 'video':
        body = 'Video';
      case 'voice':
        body = 'Voice message';
      default:
        body = message.data['preview'] as String? ?? 'New message';
    }

    await plugin.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'semya_messages',
          'Messages',
          channelDescription: 'Notifications for new messages and calls',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'chat:$conversationId',
    );
  }
}

/// Waits (bounded) for the user to act on the just-shown incoming call while
/// the main isolate is dead, and writes a decline to Firestore so the caller
/// stops ringing. Accept/end/timeout events just end the wait early — the
/// main isolate handles those when the app launches.
Future<void> _propagateBackgroundDecline(String callId) async {
  if (callId.isEmpty) return;
  try {
    final event = await FlutterCallkitIncoming.onEvent
        .where((event) => event != null)
        .cast<CallEvent>()
        .firstWhere((event) {
          final body = event.body as Map<dynamic, dynamic>? ?? {};
          if ((body['id'] as String?) != callId) return false;
          return event.event == Event.actionCallDecline ||
              event.event == Event.actionCallAccept ||
              event.event == Event.actionCallEnded ||
              event.event == Event.actionCallTimeout;
        })
        .timeout(const Duration(seconds: 60));

    if (event.event != Event.actionCallDecline) return;

    CallDebugLog.add(
      'Background decline for $callId — writing status=rejected',
      name: 'Call',
    );
    final doc = FirebaseFirestore.instance.collection('calls').doc(callId);
    final snapshot = await doc.get();
    if (!snapshot.exists || snapshot.data()?['status'] != 'ringing') return;
    await doc.update({
      'status': 'rejected',
      'endedAt': DateTime.now().toIso8601String(),
      'endReason': 'rejected',
    });
  } on TimeoutException {
    // No user action while backgrounded — let the isolate finish.
  } catch (e) {
    CallDebugLog.add('Background decline propagation failed: $e', name: 'Call');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Neither is needed to render the first frame, so start them now but don't
  // block on them. CallDebugLog.add buffers in memory until init completes,
  // and the call-recovery pass (incoming_call_overlay) only creates a peer
  // connection after platform-channel and Firestore round-trips, by which
  // point these have long finished.
  unawaited(CallDebugLog.init());
  // Required on Android — without this, createPeerConnection crashes
  // immediately. iOS initialises WebRTC automatically via the native
  // framework.
  if (defaultTargetPlatform == TargetPlatform.android) {
    unawaited(WebRTC.initialize());
  }

  // Only Firebase and SharedPreferences must be ready before runApp
  // (auth state and the locale override are read during the first build).
  final results = await Future.wait<Object?>([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    SharedPreferences.getInstance(),
  ]);
  final prefs = results[1] as SharedPreferences;

  if (kDebugMode && defaultTargetPlatform == TargetPlatform.iOS) {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}
