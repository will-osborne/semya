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
    this.verificationId,
    this.resendToken,
    this.codeSent = false,
  });

  final bool isAuthenticated;
  final fb.User? user;
  final bool isLoading;
  final String? error;
  final String? verificationId;
  final int? resendToken;
  final bool codeSent;

  AuthState copyWith({
    bool? isAuthenticated,
    fb.User? user,
    bool clearUser = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? verificationId,
    int? resendToken,
    bool? codeSent,
  }) {
    return AuthState(
      isAuthenticated:
          isAuthenticated ?? (clearUser ? false : this.isAuthenticated),
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      codeSent: codeSent ?? this.codeSent,
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

  /// Initiates phone number verification.
  ///
  /// On success, [state.codeSent] becomes true and [state.verificationId]
  /// is populated so the OTP screen can proceed.
  Future<void> verifyPhone(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true, codeSent: false);

    try {
      await _authRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          // Android auto-retrieval path.
          try {
            final result = await _authRepository.signInWithCredential(
              credential,
            );
            state = state.copyWith(
              isAuthenticated: true,
              user: result.user,
              isLoading: false,
            );
          } catch (e) {
            state = state.copyWith(isLoading: false, error: e.toString());
          }
        },
        verificationFailed: (fb.FirebaseAuthException exception) {
          state = state.copyWith(
            isLoading: false,
            error: exception.message ?? 'Verification failed.',
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            resendToken: resendToken,
            codeSent: true,
            clearError: true,
          );
        },
        codeAutoRetrievalTimeout: (_) {
          state = state.copyWith(isLoading: false);
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Signs the user in using the SMS code they received.
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
