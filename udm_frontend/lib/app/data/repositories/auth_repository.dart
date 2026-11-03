import '../../core/network/failure.dart';
import '../../core/storage/local_cache.dart';
import '../../core/storage/token_store.dart';
import '../models/session.dart';
import '../models/user_profile.dart';
import '../providers/udm_api.dart';

/// Owns the sign-in lifecycle: tokens in secure storage, the profile cached for
/// the next cold start, and nothing else. Views talk to `SessionController`.
class AuthRepository {
  AuthRepository(this._api, this._store, this._cache);

  /// The last profile the app saw online, so the Profile tab has real content
  /// before the network answers.
  static const String profileCacheKey = 'udm.auth.profile';

  final UdmApi _api;
  final TokenStore _store;
  final LocalCache _cache;

  Future<bool> hasSession() async => await _store.read() != null;

  Future<UserProfile> signIn({required String email, required String password}) async {
    final session = await _api.signIn(email: email, password: password);
    return _open(session);
  }

  Future<UserProfile> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final session = await _api.register(email: email, password: password, fullName: fullName);
    return _open(session);
  }

  /// Restores a session on launch. Null means "not signed in"; a thrown
  /// [Failure] means the device claims a session but the API disagreed.
  Future<UserProfile?> restore() async {
    if (await _store.read() == null) return null;
    return _refreshProfile();
  }

  Future<UserProfile> save(UserProfile draft) async {
    final saved = await _api.updateProfile(draft.patchPayload());
    await _cache.writeJson(profileCacheKey, saved.toJson());
    return saved;
  }

  /// Revokes the refresh token server-side, then forgets it locally.
  ///
  /// Returns false when the network refused the revocation: the student is
  /// signed out on this device, but the refresh token stays valid for its
  /// lifetime (14 days by default). Worth telling them, not hiding.
  Future<bool> signOut() async {
    final tokens = await _store.read();
    var revoked = true;
    try {
      if (tokens != null) await _api.signOut(refresh: tokens.refresh);
    } on Failure {
      revoked = false;
    } finally {
      await forget();
    }
    return revoked;
  }

  /// Drops everything the session leaves behind, including the cached profile:
  /// a name, campus and translation preference on a shared device are personal.
  Future<void> forget() async {
    await _store.clear();
    await _cache.remove(profileCacheKey);
  }

  UserProfile? cachedProfile() {
    final raw = _cache.readJson(profileCacheKey);
    return raw == null ? null : UserProfile.fromJson(raw);
  }

  Future<UserProfile> _open(Session session) async {
    await _store.write(session.tokens);
    return _refreshProfile();
  }

  Future<UserProfile> _refreshProfile() async {
    final profile = await _api.profile();
    await _cache.writeJson(profileCacheKey, profile.toJson());
    return profile;
  }
}
