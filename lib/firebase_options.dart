import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Placeholder Firebase options.
/// Replace with actual values from `flutterfire configure`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBre2wHfveECl1DAhWmv5y5L1AH3VIiL8U',
    appId: '1:831340514827:android:234d1c4c9cc93e0d2a810e',
    messagingSenderId: '831340514827',
    projectId: 'semya-a7d10',
    storageBucket: 'semya-a7d10.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBmJllq6MDSOdbIinX2uj6C0wtN-VnY0yw',
    appId: '1:831340514827:ios:aae1542e921272b72a810e',
    messagingSenderId: '831340514827',
    projectId: 'semya-a7d10',
    storageBucket: 'semya-a7d10.firebasestorage.app',
    iosBundleId: 'com.semya.semya',
  );
}
