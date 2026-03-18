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
      verificationCompleted: (credential) {
        dev.log('verifyPhoneNumber: verificationCompleted', name: 'AuthRepo');
        verificationCompleted(credential);
      },
      verificationFailed: (exception) {
        dev.log(
          'verifyPhoneNumber: verificationFailed - ${exception.code}: ${exception.message}',
          name: 'AuthRepo',
        );
        verificationFailed(exception);
      },
      codeSent: (String verificationId, int? resendToken) {
        dev.log(
          'verifyPhoneNumber: codeSent, id=$verificationId',
          name: 'AuthRepo',
        );
        resolvedVerificationId = verificationId;
        codeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (id) {
        dev.log(
          'verifyPhoneNumber: codeAutoRetrievalTimeout',
          name: 'AuthRepo',
        );
        codeAutoRetrievalTimeout(id);
      },
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
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}
