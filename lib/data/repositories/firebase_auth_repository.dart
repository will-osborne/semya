import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:semya/domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _firebaseAuth;

  @override
  Stream<fb.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  fb.User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<String> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(fb.PhoneAuthCredential) verificationCompleted,
    required void Function(fb.FirebaseAuthException) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    String resolvedVerificationId = '';

    dev.log('verifyPhoneNumber: starting for $phoneNumber', name: 'AuthRepo');
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.iOS) {
      await _firebaseAuth.setSettings(appVerificationDisabledForTesting: true);
    }
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        resolvedVerificationId = verificationId;
        codeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      forceResendingToken: forceResendingToken,
    );

    return resolvedVerificationId;
  }

  @override
  Future<fb.UserCredential> signInWithCredential(
    fb.PhoneAuthCredential credential,
  ) {
    return _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<fb.UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = fb.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    dev.log('signInWithEmailAndPassword: starting for $email', name: 'AuthRepo');
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<fb.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    dev.log(
      'createUserWithEmailAndPassword: starting for $email',
      name: 'AuthRepo',
    );
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<fb.User> linkCurrentUserWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw fb.FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user to link credentials.',
      );
    }

    final credential = fb.EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    final linked = await user.linkWithCredential(credential);
    return linked.user ?? _firebaseAuth.currentUser!;
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}
