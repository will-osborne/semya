import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:semya/config/router.dart';
import 'package:semya/data/services/call_debug_log.dart';
import 'package:semya/domain/entities/call.dart';
import 'package:semya/l10n/app_localizations.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/call_provider.dart';
import 'package:semya/providers/locale_provider.dart';
import 'package:semya/providers/notification_provider.dart';
import 'package:semya/providers/providers.dart';
import 'package:semya/providers/user_provider.dart';

class IncomingCallOverlay extends ConsumerStatefulWidget {
  const IncomingCallOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncomingCallOverlay> createState() =>
      _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay>
    with WidgetsBindingObserver {
  // Shared-preferences keys written by the iOS AppDelegate fallback
  // CXProvider when a terminated-state call is answered/declined before the
  // Flutter engine is running.
  static const _pendingAcceptedCallKey = 'pending_accepted_call';
  static const _pendingDeclinedCallKey = 'pending_declined_call';

  String? _activeCallKitId;
  String? _pendingVoipToken;
  String? _pendingAcceptedCallId;
  bool _isRecoveringAcceptedCall = false;
  bool _notificationWarningShown = false;
  StreamSubscription<RemoteMessage>? _cancelPushSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final callKitService = ref.read(callKitServiceProvider);
    unawaited(_initNotifications());

    // Foreground cancel pushes: the Firestore incoming-call stream also
    // dismisses CallKit when a call stops ringing, but the push is the
    // authoritative signal when the stream is unavailable (e.g. auth still
    // loading). Ending an unknown call id is a no-op.
    _cancelPushSub = FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] != 'call_cancelled') return;
      final callId = message.data['callId'] as String? ?? '';
      if (callId.isEmpty) return;
      CallDebugLog.add(
        'Foreground cancel push received for $callId',
        name: 'Call',
      );
      unawaited(ref.read(callKitServiceProvider).endCall(callId));
      if (_activeCallKitId == callId) _activeCallKitId = null;
    });

    callKitService.onCallAccepted = (callId) async {
      if (!mounted) return;
      _activeCallKitId = callId;
      await _handleAcceptedCall(callId);
    };

    callKitService.onCallDeclined = (callId) {
      if (!mounted) return;
      ref.read(callProvider.notifier).rejectCall(callId);
      _activeCallKitId = null;
    };

    callKitService.onCallEnded = (callId) {
      _activeCallKitId = null;
    };

    callKitService.onCallTimeout = (callId) {
      _activeCallKitId = null;
    };

    callKitService.onVoipTokenUpdated = (token) {
      if (!mounted) return;
      unawaited(_persistVoipToken(token));
    };

    callKitService.startListening();

    // Fetch and store initial VoIP token (iOS only).
    unawaited(_initVoipToken());
    unawaited(_recoverAcceptedCallIfNeeded());
  }

  /// Initializes push notifications (permission request included) and warns
  /// when the permission was denied on Android — without POST_NOTIFICATIONS
  /// (Android 13+) the CallKit-style incoming-call UI cannot be shown, so
  /// incoming calls would be completely invisible.
  Future<void> _initNotifications() async {
    await ref.read(notificationProvider.notifier).initialize();
    if (!mounted || !Platform.isAndroid || _notificationWarningShown) return;
    if (ref.read(notificationProvider).permissionGranted) return;

    _notificationWarningShown = true;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          l10n?.notificationsDisabledCallsWarning ??
              'Notifications are disabled — incoming calls will not be shown. '
                  'Enable notifications in Settings.',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: l10n?.openSettingsAction ?? 'Open Settings',
          onPressed: () {
            unawaited(openAppSettings());
          },
        ),
      ),
    );
  }

  Future<void> _initVoipToken() async {
    final callKitService = ref.read(callKitServiceProvider);
    var token = await callKitService.getVoipToken();

    // Fallback: read from shared_preferences (written by AppDelegate via
    // UserDefaults when PushKit fires before the Flutter plugin is ready).
    if (token == null || token.isEmpty) {
      final prefs = ref.read(sharedPreferencesProvider);
      token = prefs.getString('voip_push_token');
    }

    if (token != null && token.isNotEmpty && mounted) {
      await _persistVoipToken(token);
    }
  }

  Future<void> _persistVoipToken(String token) async {
    final userId = ref.read(authProvider).user?.uid;
    if (userId == null) {
      _pendingVoipToken = token;
      return;
    }
    try {
      await ref
          .read(firestoreUserRepositoryProvider)
          .setVoipToken(userId, token);
      _pendingVoipToken = null;
    } catch (error, stackTrace) {
      _pendingVoipToken = token;
      dev.log(
        'Failed to persist VoIP token: $error',
        name: 'IncomingCallOverlay',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _flushPendingVoipToken() async {
    final token = _pendingVoipToken;
    if (token == null) return;
    await _persistVoipToken(token);
  }

  Future<void> _handleAcceptedCall(String callId) async {
    if (_isRecoveringAcceptedCall) {
      _pendingAcceptedCallId = callId;
      return;
    }

    final currentUserId = ref.read(authProvider).user?.uid;
    final appUser = ref.read(userProvider).appUser;
    if (currentUserId == null || appUser == null) {
      _pendingAcceptedCallId = callId;
      return;
    }

    final activeCallId = ref.read(callProvider).activeCall?.id;
    if (activeCallId == callId) {
      _pendingAcceptedCallId = null;
      return;
    }

    _pendingAcceptedCallId = null;
    _isRecoveringAcceptedCall = true;
    try {
      final notifier = ref.read(callProvider.notifier);
      notifier.setCurrentUserId(currentUserId);
      await notifier.joinCall(callId);
      final callState = ref.read(callProvider);
      final shouldOpenCallScreen =
          callState.activeCall?.id == callId || callState.isConnecting;
      if (shouldOpenCallScreen && mounted) {
        ref.read(routerProvider).push('/call/$callId');
      }
    } finally {
      _isRecoveringAcceptedCall = false;
      final pendingCallId = _pendingAcceptedCallId;
      if (pendingCallId != null && pendingCallId != callId) {
        unawaited(_handleAcceptedCall(pendingCallId));
      }
    }
  }

  Future<void> _recoverAcceptedCallIfNeeded() async {
    if (!mounted || _isRecoveringAcceptedCall) return;

    // Terminated-state CallKit actions persisted by the iOS AppDelegate
    // fallback CXProvider (UserDefaults → shared_preferences).
    final handled = await _recoverTerminatedCallKitActions();
    if (handled || !mounted) return;

    final pendingCallId = _pendingAcceptedCallId;
    if (pendingCallId != null) {
      await _handleAcceptedCall(pendingCallId);
      return;
    }

    final activeCalls = await ref.read(callKitServiceProvider).getActiveCalls();
    for (final call in activeCalls) {
      final isAccepted = call['accepted'] == true || call['isAccepted'] == true;
      final callId = call['id'] as String?;
      if (!isAccepted || callId == null || callId.isEmpty) continue;

      // Verify the call is still active in Firestore before recovering.
      // Stale CallKit entries from previous sessions would otherwise
      // immediately navigate to the call screen on every app launch.
      final callRepo = ref.read(firestoreCallRepositoryProvider);
      final firestoreCall = await callRepo.getCall(callId);
      if (firestoreCall == null ||
          firestoreCall.status == CallStatus.ended ||
          firestoreCall.status == CallStatus.missed ||
          firestoreCall.status == CallStatus.rejected) {
        // Stale call — end it in CallKit and skip.
        ref.read(callKitServiceProvider).endCall(callId);
        continue;
      }

      _activeCallKitId = callId;
      await _handleAcceptedCall(callId);
      return;
    }
  }

  // NOTE: media permissions are intentionally NOT requested at startup.
  // Microphone (and camera, needed at call setup for the video m-line) are
  // requested when a call starts or is answered (CallNotifier), and photo
  // access is requested by the image picker at attachment time. Only the
  // notification permission is requested at startup (via _initNotifications)
  // because Android 13+ cannot show the incoming-call UI without it.

  /// Reads (then clears) call ids persisted by the iOS AppDelegate fallback
  /// CXProvider for calls answered/declined while the app was terminated.
  /// Returns true when an accepted call was recovered and is being handled.
  Future<bool> _recoverTerminatedCallKitActions() async {
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      // AppDelegate writes UserDefaults directly; reload to see fresh values.
      await prefs.reload();
    } catch (_) {}

    final callRepo = ref.read(firestoreCallRepositoryProvider);

    final declinedId = prefs.getString(_pendingDeclinedCallKey);
    if (declinedId != null && declinedId.isNotEmpty) {
      try {
        final call = await callRepo.getCall(declinedId);
        await prefs.remove(_pendingDeclinedCallKey);
        if (call != null && call.status == CallStatus.ringing) {
          CallDebugLog.add(
            'Terminated-state decline recovered for $declinedId — '
            'writing rejected',
            name: 'Call',
          );
          await ref.read(callProvider.notifier).rejectCall(declinedId);
        }
      } catch (e) {
        // Leave the key in place for the next recovery pass (e.g. auth not
        // ready yet, so the Firestore read/write was denied).
        CallDebugLog.add(
          'Failed to recover terminated-state decline: $e',
          name: 'Call',
        );
      }
    }

    final acceptedId = prefs.getString(_pendingAcceptedCallKey);
    if (acceptedId == null || acceptedId.isEmpty) return false;
    try {
      final call = await callRepo.getCall(acceptedId);
      await prefs.remove(_pendingAcceptedCallKey);
      if (call == null ||
          call.status == CallStatus.ended ||
          call.status == CallStatus.missed ||
          call.status == CallStatus.rejected) {
        // Stale id — dismiss any lingering CallKit UI and ignore.
        unawaited(ref.read(callKitServiceProvider).endCall(acceptedId));
        return false;
      }
      CallDebugLog.add(
        'Terminated-state accept recovered for $acceptedId',
        name: 'Call',
      );
      _activeCallKitId = acceptedId;
      await _handleAcceptedCall(acceptedId);
      return true;
    } catch (e) {
      // Leave the key in place for the next recovery pass.
      CallDebugLog.add(
        'Failed to recover terminated-state accept: $e',
        name: 'Call',
      );
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_recoverAcceptedCallIfNeeded());
    unawaited(ref.read(notificationProvider.notifier).flushPendingNavigation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelPushSub?.cancel();
    final callKitService = ref.read(callKitServiceProvider);
    callKitService.onCallAccepted = null;
    callKitService.onCallDeclined = null;
    callKitService.onCallEnded = null;
    callKitService.onCallTimeout = null;
    callKitService.onVoipTokenUpdated = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      unawaited(_flushPendingVoipToken());
      unawaited(_recoverAcceptedCallIfNeeded());
      unawaited(
        ref.read(notificationProvider.notifier).flushPendingNavigation(),
      );
    });
    ref.listen(userProvider, (previous, next) {
      if (next.appUser == null) return;
      unawaited(_flushPendingVoipToken());
      unawaited(_recoverAcceptedCallIfNeeded());
      unawaited(
        ref.read(notificationProvider.notifier).flushPendingNavigation(),
      );
    });

    // Surface microphone-permission denials with an actionable message —
    // call setup fails before the call screen opens, so nothing else
    // reports this error to the user.
    ref.listen(callProvider.select((s) => s.error), (previous, next) {
      if (next == null || next == previous) return;
      if (next != kCallMicPermissionError) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n?.callMicrophonePermissionRequired ??
                'Microphone access is required for calls. '
                    'Enable it in Settings.',
          ),
          action: SnackBarAction(
            label: l10n?.openSettingsAction ?? 'Open Settings',
            onPressed: () {
              unawaited(openAppSettings());
            },
          ),
        ),
      );
    });

    // Listen for incoming calls and show native CallKit UI.
    ref.listen(incomingCallProvider, (prev, next) {
      next.whenData((call) async {
        final l10n = AppLocalizations.of(context);
        if (call == null) {
          // Call disappeared (caller cancelled or callee answered).
          // Only dismiss CallKit if there's no active call — if the callee
          // just answered, the call transitions from ringing to connected
          // which makes this stream emit null, but we must NOT end CallKit.
          if (_activeCallKitId != null) {
            final hasActiveCall = ref.read(callProvider).activeCall != null;
            final isRecoveringAcceptedCall =
                _isRecoveringAcceptedCall ||
                _pendingAcceptedCallId == _activeCallKitId;
            if (!hasActiveCall && !isRecoveringAcceptedCall) {
              ref.read(callKitServiceProvider).endCall(_activeCallKitId!);
            }
            _activeCallKitId = null;
          }
          return;
        }

        // Don't show CallKit if there's already an active call.
        final hasActiveCall = ref.read(callProvider).activeCall != null;
        if (hasActiveCall) return;

        // Already showing CallKit for this call.
        if (_activeCallKitId == call.id) return;

        // Check if CallKit is already displaying this call (e.g. shown
        // natively by the PushKit VoIP handler before Dart started).
        final activeCalls = await ref
            .read(callKitServiceProvider)
            .getActiveCalls();
        final existingCallData = activeCalls
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (activeCall) => activeCall?['id'] == call.id,
              orElse: () => null,
            );
        if (existingCallData != null) {
          _activeCallKitId = call.id;
          final isAccepted =
              existingCallData['accepted'] == true ||
              existingCallData['isAccepted'] == true;
          if (isAccepted) {
            unawaited(_handleAcceptedCall(call.id));
          }
          return;
        }

        // Look up caller display name.
        final userRepo = ref.read(firestoreUserRepositoryProvider);
        final caller = await userRepo.getUser(call.callerId);
        final callerName = caller?.displayName ?? l10n?.unknown ?? 'Unknown';

        // Guard: check the call hasn't been cancelled during the async gap.
        if (!mounted) return;
        final currentIncoming = ref.read(incomingCallProvider).valueOrNull;
        if (currentIncoming?.id != call.id) return;

        _activeCallKitId = call.id;
        ref
            .read(callKitServiceProvider)
            .showIncomingCall(callId: call.id, callerName: callerName);
      });
    });

    return widget.child;
  }
}
