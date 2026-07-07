import 'package:firebase_auth/firebase_auth.dart' as fb;
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
import '../ui/screens/language/language_selection_screen.dart';
import '../ui/screens/settings/settings_screen.dart';
import '../ui/screens/settings/call_debug_screen.dart';
import '../ui/screens/call/call_screen.dart';
import '../ui/screens/group/create_group_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/user_provider.dart';

class AppRoutes {
  AppRoutes._();

  static const String languageSelect = '/select-language';
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

  /// Query flag that marks an intentional visit to profile setup (editing an
  /// existing profile) so the redirect doesn't bounce the user back home.
  static const String profileEditQuery = 'edit';
  static const String profileSetupEdit = '$profileSetup?$profileEditQuery=1';
}

/// Notifier that triggers a router refresh only when something the redirect
/// actually depends on changes — not on every transient flag flip (e.g.
/// AuthState.isLoading during a sign-in attempt).
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(hasChosenLocaleProvider, (previous, next) {
      if (previous != next) notifyListeners();
    });
    ref.listen(authProvider, (previous, next) {
      final before = previous == null ? null : _authKey(previous);
      if (before != _authKey(next)) notifyListeners();
    });
    ref.listen(userProvider, (previous, next) {
      final before = previous == null ? null : _userKey(previous);
      if (before != _userKey(next)) notifyListeners();
    });
  }

  static (bool, String?, bool) _authKey(AuthState state) => (
    state.isAuthenticated,
    state.user?.uid,
    _hasPasswordProvider(state.user),
  );

  static (UserLoadStatus, String?) _userKey(UserState state) =>
      (state.status, state.appUser?.id);

  static bool _hasPasswordProvider(fb.User? user) =>
      user?.providerData.any((info) => info.providerId == 'password') ?? false;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  // Trigger user profile load when already authenticated at startup (deferred
  // to avoid modifying another provider during this provider's
  // initialization). Later sign-ins are handled by userProvider itself, which
  // reloads whenever the authenticated uid changes.
  final authState = ref.read(authProvider);
  if (authState.isAuthenticated) {
    final userState = ref.read(userProvider);
    if (userState.status == UserLoadStatus.unknown) {
      Future.microtask(() => ref.read(userProvider.notifier).loadCurrentUser());
    }
  }

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      // First launch: force language selection before anything else.
      final hasChosenLocale = ref.read(hasChosenLocaleProvider);
      if (!hasChosenLocale) {
        return state.matchedLocation == AppRoutes.languageSelect
            ? null
            : AppRoutes.languageSelect;
      }
      if (state.matchedLocation == AppRoutes.languageSelect) {
        return AppRoutes.home;
      }

      final authState = ref.read(authProvider);
      final isLoggedIn = authState.isAuthenticated;
      final isOnPublicAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.smsMigrationPhone ||
          state.matchedLocation == AppRoutes.smsMigrationOtp;
      final isOnProtectedAuthRoute =
          state.matchedLocation == AppRoutes.linkEmailPassword ||
          state.matchedLocation == AppRoutes.profileSetup;

      if (!isLoggedIn && !isOnPublicAuthRoute && !isOnProtectedAuthRoute) {
        return AppRoutes.login;
      }

      if (!isLoggedIn && isOnProtectedAuthRoute) {
        return AppRoutes.login;
      }

      if (isLoggedIn && isOnPublicAuthRoute) {
        return AppRoutes.home;
      }

      final hasPasswordProvider = ref
          .read(authProvider.notifier)
          .hasPasswordProvider;
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

      if (isLoggedIn) {
        final userState = ref.read(userProvider);
        final profileResolved = userState.status == UserLoadStatus.loaded;

        if (state.matchedLocation != AppRoutes.profileSetup) {
          // Hold the current route until the profile lookup resolves —
          // redirecting a signed-in user to setup before loadCurrentUser
          // finishes would flash the wrong screen (cold-start race).
          if (!profileResolved) return null;
          // Resolved with no profile — go create one. A failed lookup
          // (error) is not "no profile": stay put rather than risk a
          // duplicate setup flow.
          if (userState.appUser == null && userState.error == null) {
            return AppRoutes.profileSetup;
          }
        } else {
          // On profile setup with a profile already loaded: leave, unless
          // the user came here deliberately to edit it.
          final isEditing =
              state.uri.queryParameters[AppRoutes.profileEditQuery] == '1';
          if (profileResolved && userState.appUser != null && !isEditing) {
            return AppRoutes.home;
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.languageSelect,
        name: 'select-language',
        builder: (context, state) => const LanguageSelectionScreen(),
      ),
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
