import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:semya/config/router.dart';
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
  String? _activeCallKitId;
  String? _pendingVoipToken;
  String? _pendingAcceptedCallId;
  bool _isRecoveringAcceptedCall = false;
  bool _permissionSnackbarShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final callKitService = ref.read(callKitServiceProvider);
    unawaited(ref.read(notificationProvider.notifier).initialize());

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
    unawaited(_ensureStartupIosPermissions());
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

  Future<void> _ensureStartupIosPermissions() async {
    if (!Platform.isIOS) return;

    final requiredPermissions = <Permission>[
      Permission.microphone,
      Permission.camera,
      Permission.photos,
    ];

    final statuses = await Future.wait(
      requiredPermissions.map((permission) => permission.status),
    );

    final toRequest = <Permission>[];
    for (var i = 0; i < requiredPermissions.length; i++) {
      final status = statuses[i];
      if (status.isGranted || status.isPermanentlyDenied || status.isRestricted) {
        continue;
      }
      toRequest.add(requiredPermissions[i]);
    }

    if (toRequest.isNotEmpty) {
      await toRequest.request();
    }

    final refreshedStatuses = await Future.wait(
      requiredPermissions.map((permission) => permission.status),
    );
    final hasMissingPermissions = refreshedStatuses.any(
      (status) => !status.isGranted,
    );

    if (!hasMissingPermissions || !mounted || _permissionSnackbarShown) return;
    _permissionSnackbarShown = true;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          l10n?.startupPermissionsMissing ??
              'Some permissions are still missing. Enable them in Settings.',
        ),
        action: SnackBarAction(
          label: l10n?.openSettingsAction ?? 'Open Settings',
          onPressed: () {
            unawaited(openAppSettings());
          },
        ),
      ),
    );
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
