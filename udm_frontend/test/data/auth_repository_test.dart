import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/core/storage/token_store.dart';
import 'package:udm_frontend/app/data/models/user_profile.dart';
import 'package:udm_frontend/app/data/repositories/auth_repository.dart';

import '../support/fakes.dart';

void main() {
  late FakeUdmApi api;
  late InMemoryTokenStore store;
  late LocalCache cache;
  late AuthRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache(await SharedPreferences.getInstance());
    api = FakeUdmApi()..serverProfile = sampleProfile();
    store = InMemoryTokenStore();
    repository = AuthRepository(api, store, cache);
  });

  test('signing in stores the pair and downloads the profile', () async {
    api.session = sampleSession();

    final profile = await repository.signIn(email: 'grace@udm.ac.ug', password: 'Pilgrim2026road');

    expect(profile.email, 'grace@udm.ac.ug');
    expect((await store.read())!.access, 'fresh-access');
    expect(cache.readJson(AuthRepository.profileCacheKey), isNotNull);
    expect(await repository.hasSession(), isTrue);
  });

  test('registering opens the same session the API handed back', () async {
    api.session = sampleSession(refresh: 'new-refresh');

    await repository.register(email: 'grace@udm.ac.ug', password: 'Pilgrim2026road', fullName: 'Grace Nabukeera');

    expect((await store.read())!.refresh, 'new-refresh');
  });

  test('a device with no stored session never calls the API', () async {
    expect(await repository.restore(), isNull);
    expect(api.profileCalls, 0);
    expect(await repository.hasSession(), isFalse);
  });

  test('a stored session is refreshed from the server on launch', () async {
    await store.write(const StoredTokens(access: 'a', refresh: 'r'));

    final profile = await repository.restore();

    expect(profile!.displayName, 'Grace Nabukeera');
    expect(api.profileCalls, 1);
  });

  test('a save patches only the fields the server lets the student write', () async {
    await store.write(const StoredTokens(access: 'a', refresh: 'r'));

    final saved = await repository.save(
      sampleProfile().copyWith(university: 'Uganda Martyrs University', yearOfStudy: 3),
    );

    expect(api.lastProfilePatch!.containsKey('email'), isFalse);
    expect(api.lastProfilePatch!.containsKey('display_name'), isFalse);
    expect(api.lastProfilePatch!.containsKey('photo'), isFalse);
    expect(api.lastProfilePatch!['university'], 'Uganda Martyrs University');
    expect(saved.university, 'Uganda Martyrs University');
    expect(saved.yearOfStudy, 3);
  });

  test('the cached profile survives for the next cold start', () async {
    await store.write(const StoredTokens(access: 'a', refresh: 'r'));
    await repository.restore();

    expect(repository.cachedProfile()?.email, 'grace@udm.ac.ug');
  });

  test('signing out revokes the refresh token and forgets everything', () async {
    api.session = sampleSession(refresh: 'stored-refresh');
    await repository.signIn(email: 'grace@udm.ac.ug', password: 'Pilgrim2026road');

    final revoked = await repository.signOut();

    expect(revoked, isTrue);
    expect(api.revokedRefresh, 'stored-refresh');
    expect(await store.read(), isNull);
    expect(cache.readJson(AuthRepository.profileCacheKey), isNull);
  });

  test('signing out offline still forgets the device and says it did not revoke', () async {
    api.session = sampleSession();
    await repository.signIn(email: 'grace@udm.ac.ug', password: 'Pilgrim2026road');
    api.authFailure = const Failure(FailureKind.offline, 'No connection');

    expect(await repository.signOut(), isFalse);
    expect(await store.read(), isNull);
  });

  test('a profile round-trips through the cache', () {
    final draft = sampleProfile().copyWith(
      campus: 'Nakawa',
      interests: const ['Bible study', 'Prayer chain'],
      preferredTranslationCode: 'web',
    );

    final restored = UserProfile.fromJson(draft.toJson());

    expect(restored.campus, 'Nakawa');
    expect(restored.interests, ['Bible study', 'Prayer chain']);
    expect(restored.preferredTranslationCode, 'web');
    expect(restored.yearOfStudy, isNull);
  });

  test('a blank profile reads as unfinished, not as missing data', () {
    const blank = UserProfile(email: 'a@b.c', displayName: '');

    expect(blank.hasCompletedDetails, isFalse);
    expect(blank.gender, UserProfile.unspecifiedGender);
    expect(blank.initials, 'A');
    expect(sampleProfile().initials, 'GN');
  });
}
