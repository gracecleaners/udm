import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/storage/token_store.dart';
import 'package:udm_frontend/app/data/models/article.dart';
import 'package:udm_frontend/app/data/models/content_kind.dart';
import 'package:udm_frontend/app/data/models/devotional.dart';
import 'package:udm_frontend/app/data/models/featured_verse.dart';
import 'package:udm_frontend/app/data/models/home_payload.dart';
import 'package:udm_frontend/app/data/models/session.dart';
import 'package:udm_frontend/app/data/models/user_profile.dart';
import 'package:udm_frontend/app/data/providers/udm_api.dart';
import 'package:udm_frontend/app/data/repositories/auth_repository.dart';
import 'package:udm_frontend/app/data/repositories/content_repository.dart';
import 'package:udm_frontend/app/data/repositories/home_repository.dart';

/// Test payload shaped exactly like `/api/v1/home/`.
HomePayload sampleHome() => HomePayload(
      greeting: 'Good morning, Grace',
      verse: const FeaturedVerse(
        id: 'v1',
        reference: 'Romans 12:2',
        text: 'Be not conformed to this world.',
        translationCode: 'kjv',
      ),
      devotion: const Devotional(
        id: 'd1',
        title: 'A Heart That Listens',
        scriptureReference: '1 Samuel 3:1-10',
        body: 'Eli was half asleep.\n\nListening is taught.',
        reflectionQuestions: ['What makes God\'s voice hard to hear?'],
      ),
      articles: const [Article(id: 'a1', title: 'How to Study a Chapter', body: 'Read once.', category: 'Bible study')],
      serverTime: DateTime.utc(2026, 11, 2, 7, 30),
    );

class FakeUdmApi implements UdmApi {
  HomePayload? homePayload;
  Failure? failure;
  int homeCalls = 0;

  /// What `/auth/token/` and `/auth/register/` hand back.
  Session? session;

  /// What `/users/me/` answers, and what a PATCH merges into it.
  UserProfile? serverProfile;

  /// Set to make every auth endpoint fail, offline or rejected alike.
  Failure? authFailure;

  Map<String, dynamic>? lastProfilePatch;
  String? revokedRefresh;
  final List<String> completions = [];
  int profileCalls = 0;

  @override
  Future<HomePayload> home() async {
    homeCalls++;
    if (failure != null) throw failure!;
    if (homePayload == null) throw StateError('FakeUdmApi.home() has no payload configured.');
    return homePayload!;
  }

  @override
  Future<Devotional> devotion(String id) async => sampleHome().devotion!;

  @override
  Future<Article> article(String id) async => sampleHome().articles.first;

  @override
  Future<Session> signIn({required String email, required String password}) async => _session();

  @override
  Future<Session> register({
    required String email,
    required String password,
    required String fullName,
  }) async =>
      _session();

  Session _session() {
    if (authFailure != null) throw authFailure!;
    if (session == null) throw StateError('FakeUdmApi has no session configured.');
    return session!;
  }

  @override
  Future<void> signOut({required String refresh}) async {
    if (authFailure != null) throw authFailure!;
    revokedRefresh = refresh;
  }

  @override
  @override
  Future<UserProfile> profile() async {
    profileCalls++;
    if (authFailure != null) throw authFailure!;
    if (serverProfile == null) throw StateError('FakeUdmApi has no profile configured.');
    return serverProfile!;
  }

  @override
  Future<UserProfile> updateProfile(Map<String, dynamic> changes) async {
    if (authFailure != null) throw authFailure!;
    if (serverProfile == null) throw StateError('FakeUdmApi has no profile configured.');
    lastProfilePatch = changes;
    serverProfile = UserProfile.fromJson({...serverProfile!.toJson(), ...changes});
    return serverProfile!;
  }

  @override
  Future<void> markComplete({required String kind, required String contentId, String? note}) async {
    if (authFailure != null) throw authFailure!;
    completions.add('$kind:$contentId');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({this.payload, this.failure});

  HomePayload? payload;
  Failure? failure;
  int loadCalls = 0;

  @override
  Future<HomePayload> load() async {
    loadCalls++;
    if (failure != null) throw failure!;
    if (payload == null) throw StateError('FakeHomeRepository has no payload configured.');
    return payload!;
  }

  @override
  HomePayload? cached() => null;

  @override
  Future<void> clearCache() async {}
}

/// A signed-in student exactly as `GET /api/v1/users/me/` answers for one whose
/// onboarding answers are still blank.
UserProfile sampleProfile() => const UserProfile(
      email: 'grace@udm.ac.ug',
      displayName: 'Grace Nabukeera',
      fullName: 'Grace Nabukeera',
      preferredTranslationCode: 'kjv',
    );

Session sampleSession({String refresh = 'stored-refresh'}) => Session(
      tokens: StoredTokens(access: 'fresh-access', refresh: refresh),
      user: const AuthUser(
        id: 'u1',
        email: 'grace@udm.ac.ug',
        displayName: 'Grace Nabukeera',
        emailVerified: false,
      ),
    );

/// Stands in for the keystore so session tests never touch a platform channel.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._tokens]);

  StoredTokens? _tokens;

  int clears = 0;

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async {
    clears++;
    _tokens = null;
  }
}

/// Session state the screens can be driven against, without a network or a
/// keystore.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.profile, this.hasSessionValue = false});

  UserProfile? profile;
  bool hasSessionValue;

  /// Thrown by sign-in, registration, restore and save.
  Failure? failure;

  /// False models an offline sign-out: forgotten locally, not revoked remotely.
  bool revokeSucceeds = true;

  int signInCalls = 0;
  int registerCalls = 0;
  int restoreCalls = 0;
  int signOutCalls = 0;
  Map<String, dynamic>? savedChanges;

  @override
  Future<bool> hasSession() async => hasSessionValue;

  @override
  Future<UserProfile> signIn({required String email, required String password}) async {
    signInCalls++;
    return _result();
  }

  @override
  Future<UserProfile> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    registerCalls++;
    return _result();
  }

  @override
  Future<UserProfile?> restore() async {
    restoreCalls++;
    return hasSessionValue ? _result() : null;
  }

  @override
  Future<UserProfile> save(UserProfile draft) async {
    savedChanges = draft.patchPayload();
    profile = draft;
    return _result();
  }

  @override
  Future<bool> signOut() async {
    signOutCalls++;
    hasSessionValue = false;
    profile = null;
    return revokeSucceeds;
  }

  @override
  Future<void> forget() async => hasSessionValue = false;

  @override
  UserProfile? cachedProfile() => profile;

  Future<UserProfile> _result() async {
    if (failure != null) throw failure!;
    if (profile == null) throw StateError('FakeAuthRepository has no profile configured.');
    return profile!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class FakeContentRepository implements ContentRepository {
  FakeContentRepository({this.serverDevotional});

  Devotional? serverDevotional;
  Failure? failure;
  Failure? progressFailure;
  final List<String> completions = [];

  @override
  Future<Devotional> devotional(String id) async {
    if (failure != null) throw failure!;
    if (serverDevotional == null) throw StateError('FakeContentRepository has no devotional configured.');
    return serverDevotional!;
  }

  @override
  Future<void> recordCompletion({required ContentKind kind, required String id}) async {
    if (progressFailure != null) throw progressFailure!;
    completions.add('${kind.value}:$id');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}
