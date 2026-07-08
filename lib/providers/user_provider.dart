import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:semya/domain/entities/user.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/notification_provider.dart';
import 'package:semya/providers/providers.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Profile-load lifecycle: [unknown] until a load has been attempted, so the
/// router can distinguish "not looked yet" from "looked and found nothing".
enum UserLoadStatus { unknown, loading, loaded }

class UserState {
  const UserState({
    this.appUser,
    this.status = UserLoadStatus.unknown,
    this.error,
  });

  final AppUser? appUser;
  final UserLoadStatus status;
  final String? error;

  bool get isLoading => status == UserLoadStatus.loading;

  UserState copyWith({
    AppUser? appUser,
    bool clearUser = false,
    UserLoadStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return UserState(
      appUser: clearUser ? null : (appUser ?? this.appUser),
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class UserNotifier extends StateNotifier<UserState> {
  UserNotifier(this._ref) : super(const UserState());

  final Ref _ref;

  /// Clears all loaded profile state (e.g. after sign-out or user switch).
  void reset() {
    state = const UserState();
  }

  /// Loads the current user's AppUser document from Firestore.
  Future<void> loadCurrentUser() async {
    final firebaseUser = _ref.read(authProvider).user;
    if (firebaseUser == null) return;

    state = state.copyWith(status: UserLoadStatus.loading, clearError: true);
    try {
      final userRepo = _ref.read(firestoreUserRepositoryProvider);
      var appUser = await userRepo.getUser(firebaseUser.uid);

      // Backfill email field for existing users who signed up before it was added.
      if (appUser != null &&
          appUser.email == null &&
          firebaseUser.email != null) {
        final updated = appUser.copyWith(email: firebaseUser.email);
        await userRepo.updateUser(updated);
        appUser = updated;
      }

      state = state.copyWith(appUser: appUser, status: UserLoadStatus.loaded);

      if (appUser != null) {
        final notifications = _ref.read(notificationProvider.notifier);
        await notifications.initialize();
        await notifications.syncTokenIfPossible();
        await notifications.flushPendingNavigation();
      }
    } catch (e) {
      state = state.copyWith(
        status: UserLoadStatus.loaded,
        error: e.toString(),
      );
    }
  }

  /// Creates a new AppUser document in Firestore.
  Future<void> createProfile(String displayName) async {
    final firebaseUser = _ref.read(authProvider).user;
    if (firebaseUser == null) {
      state = state.copyWith(error: 'Not authenticated.');
      return;
    }

    state = state.copyWith(status: UserLoadStatus.loading, clearError: true);
    try {
      final userRepo = _ref.read(firestoreUserRepositoryProvider);

      final appUser = AppUser(
        id: firebaseUser.uid,
        phoneNumber: firebaseUser.phoneNumber ?? firebaseUser.email ?? '',
        email: firebaseUser.email?.toLowerCase(),
        displayName: displayName,
        createdAt: DateTime.now(),
        deviceIds: const ['1'],
      );

      dev.log('createProfile: creating user doc...', name: 'UserNotifier');
      await userRepo.createUser(appUser);
      dev.log('createProfile: user doc created', name: 'UserNotifier');

      state = state.copyWith(appUser: appUser, status: UserLoadStatus.loaded);
      _ref.invalidate(userByIdProvider(appUser.id));

      final notifications = _ref.read(notificationProvider.notifier);
      await notifications.initialize();
      await notifications.syncTokenIfPossible();
      await notifications.flushPendingNavigation();
    } catch (e, st) {
      dev.log(
        'createProfile failed: $e',
        name: 'UserNotifier',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        status: UserLoadStatus.loaded,
        error: e.toString(),
      );
    }
  }

  /// Updates the current user's profile fields.
  Future<void> updateProfile({String? displayName}) async {
    final current = state.appUser;
    if (current == null) return;

    state = state.copyWith(status: UserLoadStatus.loading, clearError: true);
    try {
      final userRepo = _ref.read(firestoreUserRepositoryProvider);
      final updated = current.copyWith(
        displayName: displayName ?? current.displayName,
      );
      await userRepo.updateUser(updated);
      state = state.copyWith(appUser: updated, status: UserLoadStatus.loaded);
      // Drop the cached lookup so other screens see the new profile.
      _ref.invalidate(userByIdProvider(updated.id));
    } catch (e) {
      state = state.copyWith(
        status: UserLoadStatus.loaded,
        error: e.toString(),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final notifier = UserNotifier(ref);
  // Keep the profile in sync with the signed-in Firebase user: clear it on
  // sign-out, (re)load it when a different user signs in.
  ref.listen(authProvider.select((state) => state.user?.uid), (previous, next) {
    if (next == null) {
      notifier.reset();
    } else if (previous != next) {
      unawaited(notifier.loadCurrentUser());
    }
  });
  return notifier;
});

/// How long a resolved user lookup stays cached after its last listener goes
/// away. Bounded so remote profile edits eventually propagate.
const _kUserCacheDuration = Duration(minutes: 15);

/// Looks up any user by their ID. Single cached source for user lookups
/// (conversation titles, call screens, etc.). Successful lookups are kept
/// alive for [_kUserCacheDuration]; failures are not cached.
final userByIdProvider = FutureProvider.autoDispose.family<AppUser?, String>((
  ref,
  userId,
) async {
  final userRepo = ref.watch(firestoreUserRepositoryProvider);
  final user = await userRepo.getUser(userId);

  final link = ref.keepAlive();
  final timer = Timer(_kUserCacheDuration, link.close);
  ref.onDispose(timer.cancel);

  return user;
});
