import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:semya/domain/repositories/auth_repository.dart';
import 'package:semya/providers/providers.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.isLoading = false,
    this.error,
  });

  final bool isAuthenticated;
  final fb.User? user;
  final bool isLoading;
  final String? error;

  AuthState copyWith({
    bool? isAuthenticated,
    fb.User? user,
    bool clearUser = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isAuthenticated:
          isAuthenticated ?? (clearUser ? false : this.isAuthenticated),
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(
        AuthState(
          isAuthenticated: authRepository.currentUser != null,
          user: authRepository.currentUser,
        ),
      ) {
    _authSubscription = _authRepository.authStateChanges.listen(_onAuthChange);
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<fb.User?> _authSubscription;

  void _onAuthChange(fb.User? user) {
    state = state.copyWith(
      isAuthenticated: user != null,
      user: user,
      clearUser: user == null,
      isLoading: false,
    );
  }

  bool get hasPasswordProvider {
    final user = state.user;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'password');
  }

  Future<String> requestSmsCode(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final completer = Completer<String>();

    try {
      await _authRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          try {
            final result = await _authRepository.signInWithCredential(
              credential,
            );
            state = state.copyWith(
              isAuthenticated: true,
              user: result.user,
              isLoading: false,
            );
            if (!completer.isCompleted) completer.complete('');
          } catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
            state = state.copyWith(isLoading: false, error: e.toString());
          }
        },
        verificationFailed: (fb.FirebaseAuthException exception) {
          if (!completer.isCompleted) {
            completer.completeError(
              exception.message ?? 'Phone verification failed.',
            );
          }
          state = state.copyWith(
            isLoading: false,
            error: exception.message ?? 'Phone verification failed.',
          );
        },
        codeSent: (String verificationId, int? _) {
          state = state.copyWith(isLoading: false, clearError: true);
          if (!completer.isCompleted) completer.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
      );

      return await completer.future;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authRepository.signInWithSmsCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      state = state.copyWith(
        isAuthenticated: true,
        user: result.user,
        isLoading: false,
      );
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(
        isAuthenticated: true,
        user: result.user,
        isLoading: false,
      );
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createAccountWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authRepository.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(
        isAuthenticated: true,
        user: result.user,
        isLoading: false,
      );
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> linkEmailPasswordToCurrentUser({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final linkedUser = await _authRepository.linkCurrentUserWithEmailPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(
        isAuthenticated: true,
        user: linkedUser,
        isLoading: false,
      );
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Signs the current user out and resets all auth state.
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepository.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(firebaseAuthRepositoryProvider);
  return AuthNotifier(authRepository: authRepository);
});
