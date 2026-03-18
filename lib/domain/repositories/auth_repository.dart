import 'package:firebase_auth/firebase_auth.dart' as fb;

abstract class AuthRepository {
  Stream<fb.User?> get authStateChanges;
  fb.User? get currentUser;
  Future<String> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(fb.PhoneAuthCredential) verificationCompleted,
    required void Function(fb.FirebaseAuthException) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  });
  Future<fb.UserCredential> signInWithCredential(
    fb.PhoneAuthCredential credential,
  );
  Future<fb.UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  });
  Future<void> signOut();
}
