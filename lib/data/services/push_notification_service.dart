import 'dart:developer' as dev;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  static const _androidChannel = AndroidNotificationChannel(
    'semya_messages',
    'Messages',
    description: 'Notifications for new messages and calls',
    importance: Importance.high,
  );

  /// Initializes the local notification plugin and creates the Android channel.
  Future<void> initialize({void Function(NotificationResponse)? onTap}) async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onTap,
    );

    // Create the Android notification channel.
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  /// Requests notification permission from the OS.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    dev.log(
      'Notification permission: ${settings.authorizationStatus}',
      name: 'PushNotificationService',
    );
    return granted;
  }

  /// Returns the current FCM token, or null if unavailable.
  Future<String?> getToken() => _messaging.getToken();

  /// Stream that emits a new token whenever FCM refreshes it.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Stream of foreground messages.
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  /// Returns the message that launched the app from a terminated state, if any.
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  /// Stream of messages that were tapped while the app was in background.
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  /// Shows a local notification for a foreground FCM message.
  Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _payloadFromData(message.data),
    );
  }

  /// Encodes message data map into a simple payload string for tap routing.
  String _payloadFromData(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    if (type == 'message') {
      return 'chat:${data['conversationId']}';
    } else if (type == 'call') {
      return 'call:${data['callId']}';
    }
    return '';
  }
}
