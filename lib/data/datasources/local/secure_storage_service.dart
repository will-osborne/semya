import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _dbPasswordKey = 'semya_db_password';
  static const int _passwordLength = 32;

  /// Returns the existing database password, generating and storing one on
  /// first call.
  Future<String> getDbPassword() async {
    final existing = await _storage.read(key: _dbPasswordKey);
    if (existing != null) {
      return existing;
    }

    final password = _generateRandomPassword(_passwordLength);
    await _storage.write(key: _dbPasswordKey, value: password);
    return password;
  }

  Future<void> setDbPassword(String password) async {
    await _storage.write(key: _dbPasswordKey, value: password);
  }

  Future<void> deleteDbPassword() async {
    await _storage.delete(key: _dbPasswordKey);
  }

  String _generateRandomPassword(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final rng = Random.secure();
    return List.generate(
      length,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }
}
