import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:semya/domain/entities/user.dart';
import 'package:semya/providers/auth_provider.dart';
import 'package:semya/providers/notification_provider.dart';
import 'package:semya/providers/providers.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class UserState {
  const UserState({this.appUser, this.isLoading = false, this.error});

  final AppUser? appUser;
  final bool isLoading;
  final String? error;

  UserState copyWith({
    AppUser? appUser,
    bool clearUser = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return UserState(
      appUser: clearUser ? null : (appUser ?? this.appUser),
      isLoading: isLoading ?? this.isLoading,
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

  /// Loads the current user's AppUser document from Firestore.
  Future<void> loadCurrentUser() async {
    final firebaseUser = _ref.read(authProvider).user;
    if (firebaseUser == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userRepo = _ref.read(firestoreUserRepositoryProvider);
      final appUser = await userRepo.getUser(firebaseUser.uid);
      state = state.copyWith(appUser: appUser, isLoading: false);

      if (appUser != null) {
        final notifications = _ref.read(notificationProvider.notifier);
        await notifications.initialize();
        await notifications.syncTokenIfPossible();
        await notifications.flushPendingNavigation();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Creates a new AppUser document in Firestore.
  Future<void> createProfile(String displayName) async {
    final firebaseUser = _ref.read(authProvider).user;
    if (firebaseUser == null) {
      state = state.copyWith(error: 'Not authenticated.');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userRepo = _ref.read(firestoreUserRepositoryProvider);

      final appUser = AppUser(
        id: firebaseUser.uid,
        phoneNumber: firebaseUser.phoneNumber ?? '',
        displayName: displayName,
        createdAt: DateTime.now(),
        deviceIds: const ['1'],
      );

      dev.log('createProfile: creating user doc...', name: 'UserNotifier');
      await userRepo.createUser(appUser);
      dev.log('createProfile: user doc created', name: 'UserNotifier');

      state = state.copyWith(appUser: appUser, isLoading: false);

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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Updates the current user's profile fields.
  Future<void> updateProfile({String? displayName}) async {
    final current = state.appUser;
    if (current == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userRepo = _ref.read(firestoreUserRepositoryProvider);
      final updated = current.copyWith(
        displayName: displayName ?? current.displayName,
      );
      await userRepo.updateUser(updated);
      state = state.copyWith(appUser: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref);
});

/// Looks up any user by their ID. Returns their AppUser (with displayName).
final userByIdProvider = FutureProvider.family<AppUser?, String>((ref, userId) {
  final userRepo = ref.watch(firestoreUserRepositoryProvider);
  return userRepo.getUser(userId);
});
