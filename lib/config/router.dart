import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/screens/auth/phone_input_screen.dart';
import '../ui/screens/auth/otp_screen.dart';
import '../ui/screens/auth/profile_setup_screen.dart';
import '../ui/screens/home/home_screen.dart';
import '../ui/screens/chat/chat_screen.dart';
import '../ui/screens/settings/settings_screen.dart';
import '../ui/screens/call/call_screen.dart';
import '../ui/screens/group/create_group_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String otp = '/otp';
  static const String profileSetup = '/profile-setup';
  static const String home = '/';
  static const String chat = '/chat/:conversationId';
  static const String settings = '/settings';
  static const String createGroup = '/create-group';
  static const String call = '/call/:callId';
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
      final isOnAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.otp ||
          state.matchedLocation == AppRoutes.profileSetup;

      if (!isLoggedIn && !isOnAuthRoute) {
        return AppRoutes.login;
      }

      if (isLoggedIn && state.matchedLocation == AppRoutes.login) {
        return AppRoutes.home;
      }

      // Wait for user profile to load before deciding.
      if (isLoggedIn && !isOnAuthRoute) {
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
        path: AppRoutes.otp,
        name: 'otp',
        builder: (context, state) => const OtpScreen(),
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
    ],
  );
});
