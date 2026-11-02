import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small key/value layer over SharedPreferences. It stores primitives only;
/// models and cache keys belong to the repositories that own them.
class LocalCache {
  LocalCache(this._prefs);

  final SharedPreferences _prefs;

  Future<void> writeJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Map<String, dynamic>? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      // A damaged cache must never brick the app; drop it and refetch.
      _prefs.remove(key);
      return null;
    }
  }

  bool flag(String key) => _prefs.getBool(key) ?? false;

  Future<void> setFlag(String key, bool value) => _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}
