import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A JWT pair as handed back by `/api/v1/auth/token/`.
class StoredTokens {
  const StoredTokens({required this.access, required this.refresh});

  final String access;
  final String refresh;

  Map<String, dynamic> toJson() => {'access': access, 'refresh': refresh};

  factory StoredTokens.fromJson(Map<String, dynamic> json) => StoredTokens(
        access: json['access'] as String,
        refresh: json['refresh'] as String,
      );
}

/// Where the session tokens live. The rest of the app never holds a token in a
/// plain field, so signing out has exactly one thing to erase.
abstract class TokenStore {
  Future<StoredTokens?> read();

  Future<void> write(StoredTokens tokens);

  Future<void> clear();
}

/// Tokens in the platform keystore / Keychain, with an in-memory mirror so the
/// interceptor can attach a header without a platform call per request.
///
/// On web `flutter_secure_storage` falls back to `localStorage`, which is not
/// encrypted; that is acceptable for a student app whose tokens are short
/// lived, but a web release should move revocation onto the server instead.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const String accessKey = 'udm.auth.access';
  static const String refreshKey = 'udm.auth.refresh';

  final FlutterSecureStorage _storage;

  StoredTokens? _cached;
  bool _loaded = false;

  @override
  Future<StoredTokens?> read() async {
    if (_loaded) return _cached;
    _loaded = true;
    final access = await _storage.read(key: accessKey);
    final refresh = await _storage.read(key: refreshKey);
    _cached = access == null || refresh == null ? null : StoredTokens(access: access, refresh: refresh);
    return _cached;
  }

  @override
  Future<void> write(StoredTokens tokens) async {
    _loaded = true;
    _cached = tokens;
    await _storage.write(key: accessKey, value: tokens.access);
    await _storage.write(key: refreshKey, value: tokens.refresh);
  }

  @override
  Future<void> clear() async {
    _loaded = true;
    _cached = null;
    await _storage.delete(key: accessKey);
    await _storage.delete(key: refreshKey);
  }
}
