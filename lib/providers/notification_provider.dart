import 'dart:async';
import 'dart:developer' as dev;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:semya/config/router.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/conversation_provider.dart';
import 'package:semya/providers/providers.dart';
import 'package:semya/providers/user_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class NotificationState {
  const NotificationState({
    this.token,
    this.permissionGranted = false,
    this.initialized = false,
    this.pendingRoutePath,
  });

  final String? token;
  final bool permissionGranted;
  final bool initialized;
  final String? pendingRoutePath;

  NotificationState copyWith({
    String? token,
    bool clearToken = false,
    bool? permissionGranted,
    bool? initialized,
    String? pendingRoutePath,
    bool clearPendingRoutePath = false,
  }) {
    return NotificationState(
      token: clearToken ? null : (token ?? this.token),
      permissionGranted: permissionGranted ?? this.permissionGranted,
      initialized: initialized ?? this.initialized,
      pendingRoutePath: clearPendingRoutePath
          ? null
          : (pendingRoutePath ?? this.pendingRoutePath),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier(this._ref) : super(const NotificationState());

  final Ref _ref;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _backgroundTapSub;
  Future<void>? _initializationFuture;

  /// Full initialization: local notifications, permission, token, listeners.
  Future<void> initialize() async {
    if (state.initialized) {
      await flushPendingNavigation();
      await syncTokenIfPossible();
      return;
    }
    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }

    _initializationFuture = _initializeInternal();
    try {
      await _initializationFuture;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initializeInternal() async {
    if (state.initialized) return;

    final service = _ref.read(pushNotificationServiceProvider);
    String? token;

    // 1. Initialize local notification plugin with tap handler.
    await service.initialize(onTap: _onLocalNotificationTap);

    // 2. Register tap listeners early so cold-start/background launches are
    // handled even if notification permission is denied or auth is still loading.
    _backgroundTapSub ??= service.onMessageOpenedApp.listen(_onMessageTap);

    final initialMessage = await service.getInitialMessage();
    if (initialMessage != null) {
      _onMessageTap(initialMessage);
    }

    // 3. Request permission.
    final granted = await service.requestPermission();
    state = state.copyWith(permissionGranted: granted);
    if (granted) {
      // 4. Get FCM token and store in Firestore.
      //    This can fail on iOS simulators (no APNs support).
      try {
        token = await service.getToken();
      } catch (e) {
        dev.log(
          'FCM token unavailable (simulator?): $e',
          name: 'NotificationNotifier',
        );
      }
      if (token != null) {
        state = state.copyWith(token: token);
        await _storeToken(token);
      }
    } else {
      dev.log('Notification permission denied', name: 'NotificationNotifier');
    }

    // 5. Listen for token refresh regardless of current auth state.
    _tokenRefreshSub ??= service.onTokenRefresh.listen(_onTokenRefresh);

    // 6. Foreground message display.
    // Calls are handled by IncomingCallOverlay via Firestore listener,
    // which shows the native CallKit/Android call UI. Skip showing a
    // regular notification for calls.
    _foregroundSub ??= service.onMessage.listen((message) {
      if (message.data['type'] == 'call') return;
      if (!state.permissionGranted) return;
      final activeConversationId = _ref.read(activeConversationIdProvider);
      final conversationId = message.data['conversationId'] as String?;
      if (activeConversationId != null &&
          activeConversationId == conversationId) {
        return;
      }
      service.showLocalNotification(message);
    });

    state = state.copyWith(initialized: true);
    await syncTokenIfPossible();
    await flushPendingNavigation();
    dev.log(
      'Notifications initialized (token=$token)',
      name: 'NotificationNotifier',
    );
  }

  /// Removes the current FCM token from Firestore. Call before sign-out.
  Future<void> removeToken() async {
    final token = state.token;
    if (token == null) return;

    final userId = _ref.read(authProvider).user?.uid;
    if (userId == null) return;

    try {
      final userRepo = _ref.read(firestoreUserRepositoryProvider);
      await userRepo.removeFcmToken(userId, token);
      dev.log(
        'Removed FCM token for user $userId',
        name: 'NotificationNotifier',
      );
    } catch (e) {
      dev.log(
        'Failed to remove FCM token: $e',
        name: 'NotificationNotifier',
        error: e,
      );
    }

    state = state.copyWith(
      clearToken: true,
      initialized: false,
      clearPendingRoutePath: true,
    );
  }

  // -----------------------------------------------------------------------
  // Private helpers
  // -----------------------------------------------------------------------

  Future<void> _storeToken(String token) async {
    final userId = _ref.read(authProvider).user?.uid;
    if (userId == null) return;

    try {
      final userRepo = _ref.read(firestoreUserRepositoryProvider);
      await userRepo.addFcmToken(userId, token);
    } catch (e) {
      dev.log(
        'Failed to store FCM token: $e',
        name: 'NotificationNotifier',
        error: e,
      );
    }
  }

  Future<void> syncTokenIfPossible() async {
    final token = state.token;
    if (token == null || token.isEmpty) return;
    if (_ref.read(authProvider).user?.uid == null) return;
    await _storeToken(token);
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final oldToken = state.token;

    // Remove old token, add new one.
    if (oldToken != null) {
      final userId = _ref.read(authProvider).user?.uid;
      if (userId != null) {
        final userRepo = _ref.read(firestoreUserRepositoryProvider);
        await userRepo.removeFcmToken(userId, oldToken);
      }
    }

    await _storeToken(newToken);
    state = state.copyWith(token: newToken);
    dev.log('FCM token refreshed', name: 'NotificationNotifier');
  }

  /// Routes the user based on FCM message data when a notification is tapped.
  void _onMessageTap(RemoteMessage message) {
    unawaited(_navigateFromData(message.data));
  }

  /// Routes the user based on local notification payload when tapped.
  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split(':');
    if (parts.length < 2) return;

    final type = parts[0];
    final id = parts.sublist(1).join(':');

    if (type == 'chat') {
      unawaited(_navigateOrQueue('/chat/$id'));
    } else if (type == 'call') {
      unawaited(_navigateOrQueue('/call/$id'));
    }
  }

  Future<void> _navigateFromData(Map<String, dynamic> data) async {
    final type = data['type'] as String?;

    if (type == 'message') {
      final conversationId = data['conversationId'] as String?;
      if (conversationId != null) {
        await _navigateOrQueue('/chat/$conversationId');
      }
    } else if (type == 'call') {
      final callId = data['callId'] as String?;
      if (callId != null) {
        await _navigateOrQueue('/call/$callId');
      }
    }
  }

  bool _canNavigateNow() {
    final authState = _ref.read(authProvider);
    if (!authState.isAuthenticated) return false;

    final userState = _ref.read(userProvider);
    if (userState.isLoading || userState.appUser == null) return false;

    return true;
  }

  Future<void> _navigateOrQueue(String path) async {
    if (!_canNavigateNow()) {
      state = state.copyWith(pendingRoutePath: path);
      return;
    }

    final router = _ref.read(routerProvider);
    state = state.copyWith(clearPendingRoutePath: true);
    // Defer to the next frame so the push happens after GoRouter has finished
    // its initial redirect cycle. Calling push() during the first build can
    // silently lose the navigation when the router is still settling.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      router.push(path);
    });
  }

  Future<void> flushPendingNavigation() async {
    final path = state.pendingRoutePath;
    if (path == null || path.isEmpty) return;
    await _navigateOrQueue(path);
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _backgroundTapSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
      return NotificationNotifier(ref);
    });
