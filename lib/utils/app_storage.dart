import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cross-platform storage facade.
/// - Web: shared_preferences (localStorage-backed, no WebCrypto requirement)
/// - Mobile/Desktop: flutter_secure_storage
class AppStorage {
  const AppStorage();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<String?> read({required String key}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }

    return _secureStorage.read(key: key);
  }

  Future<void> write({required String key, required String value}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }

    await _secureStorage.write(key: key, value: value);
  }

  Future<void> delete({required String key}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }

    await _secureStorage.delete(key: key);
  }

  Future<void> deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      return;
    }

    await _secureStorage.deleteAll();
  }
}
