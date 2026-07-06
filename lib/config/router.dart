import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/screens/auth/link_email_password_screen.dart';
import '../ui/screens/auth/phone_input_screen.dart';
import '../ui/screens/auth/profile_setup_screen.dart';
import '../ui/screens/auth/sms_migration_otp_screen.dart';
import '../ui/screens/auth/sms_migration_phone_screen.dart';
import '../ui/screens/home/home_screen.dart';
import '../ui/screens/chat/chat_screen.dart';
import '../ui/screens/settings/settings_screen.dart';
import '../ui/screens/settings/call_debug_screen.dart';
import '../ui/screens/call/call_screen.dart';
import '../ui/screens/group/create_group_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String smsMigrationPhone = '/migrate-sms';
  static const String smsMigrationOtp = '/migrate-sms-otp';
  static const String linkEmailPassword = '/link-email-password';
  static const String profileSetup = '/profile-setup';
  static const String home = '/';
  static const String chat = '/chat/:conversationId';
  static const String settings = '/settings';
  static const String createGroup = '/create-group';
  static const String call = '/call/:callId';
  static const String callDebug = '/call-debug';
}

/// Notifier that triggers router refresh when auth or user state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(userProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  // Trigger user profile load when authenticated (deferred to avoid
  // modifying another provider during this provider's initialization).
  final authState = ref.read(authProvider);
  if (authState.isAuthenticated) {
    final userState = ref.read(userProvider);
    if (userState.appUser == null && !userState.isLoading) {
      Future.microtask(() => ref.read(userProvider.notifier).loadCurrentUser());
    }
  }

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.isAuthenticated;
      final isOnPublicAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.smsMigrationPhone ||
          state.matchedLocation == AppRoutes.smsMigrationOtp;
      final isOnProtectedAuthRoute =
          state.matchedLocation == AppRoutes.linkEmailPassword ||
          state.matchedLocation == AppRoutes.profileSetup;

      if (!isLoggedIn &&
          !isOnPublicAuthRoute &&
          !isOnProtectedAuthRoute) {
        return AppRoutes.login;
      }

      if (!isLoggedIn && isOnProtectedAuthRoute) {
        return AppRoutes.login;
      }

      if (isLoggedIn &&
          (state.matchedLocation == AppRoutes.login ||
              state.matchedLocation == AppRoutes.smsMigrationPhone ||
              state.matchedLocation == AppRoutes.smsMigrationOtp)) {
        return AppRoutes.home;
      }

      final hasPasswordProvider = ref.read(authProvider.notifier).hasPasswordProvider;
      if (isLoggedIn &&
          !hasPasswordProvider &&
          state.matchedLocation != AppRoutes.linkEmailPassword &&
          state.matchedLocation != AppRoutes.profileSetup) {
        return AppRoutes.linkEmailPassword;
      }
      if (isLoggedIn &&
          hasPasswordProvider &&
          state.matchedLocation == AppRoutes.linkEmailPassword) {
        return AppRoutes.home;
      }

      // Wait for user profile to load before deciding.
      if (isLoggedIn && state.matchedLocation != AppRoutes.profileSetup) {
        final userState = ref.read(userProvider);
        // Still loading — don't redirect yet.
        if (userState.isLoading) return null;
        // Loaded but no profile — go to setup.
        if (userState.appUser == null) return AppRoutes.profileSetup;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: AppRoutes.smsMigrationPhone,
        name: 'sms-migration-phone',
        builder: (context, state) => const SmsMigrationPhoneScreen(),
      ),
      GoRoute(
        path: AppRoutes.smsMigrationOtp,
        name: 'sms-migration-otp',
        builder: (context, state) => const SmsMigrationOtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.linkEmailPassword,
        name: 'link-email-password',
        builder: (context, state) => const LinkEmailPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        name: 'profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          return ChatScreen(conversationId: conversationId);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createGroup,
        name: 'create-group',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: AppRoutes.call,
        name: 'call',
        builder: (context, state) {
          final callId = state.pathParameters['callId']!;
          return CallScreen(callId: callId);
        },
      ),
      GoRoute(
        path: AppRoutes.callDebug,
        name: 'call-debug',
        builder: (context, state) => const CallDebugScreen(),
      ),
    ],
  );
});
