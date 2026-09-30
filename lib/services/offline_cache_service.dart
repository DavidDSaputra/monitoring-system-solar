import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  OfflineCacheService._();

  static const _prefix = 'solarview.offline.';

  static Future<void> writeJson(String key, dynamic value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('$_prefix$key', jsonEncode(value));
      await preferences.setInt(
        '$_prefix$key.updatedAt',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Live data must remain usable even if local storage is unavailable.
    }
  }

  static Future<dynamic> readJson(String key) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('$_prefix$key');
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> lastUpdated(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final milliseconds = preferences.getInt('$_prefix$key.updatedAt');
    return milliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
