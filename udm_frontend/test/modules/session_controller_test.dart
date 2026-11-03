import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/core/storage/token_store.dart';
import 'package:udm_frontend/app/data/models/user_profile.dart';
import 'package:udm_frontend/app/data/repositories/auth_repository.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeUdmApi api;
  late InMemoryTokenStore store;
  late LocalCache cache;
  late AuthRepository repository;
  late ApiClient client;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache(await SharedPreferences.getInstance());
    api = FakeUdmApi()..serverProfile = sampleProfile();
    store = InMemoryTokenStore();
    repository = AuthRepository(api, store, cache);
    // Nothing here talks to a server; the client exists so the controller can
    // be handed the real interceptor it listens to.
    client = ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1/api/v1')),
      tokenStore: store,
    );
  });

  tearDown(() {
    Get.reset();
    client.close();
  });

  Future<SessionController> start() async {
    final controller = Get.put(SessionController(repository, client));
    await controller.restore();
    return controller;
  }

  test('a fresh device starts signed out, without calling the API', () async {
    final controller = await start();

    expect(controller.status.value, SessionStatus.signedOut);
    expect(controller.profile.value, isNull);
    expect(api.profileCalls, 0);
  });

  test('a stored session is restored into the profile', () async {
    await store.write(const StoredTokens(access: 'a', refresh: 'r'));

    final controller = await start();

    expect(controller.status.value, SessionStatus.signedIn);
    expect(controller.profile.value?.email, 'grace@udm.ac.ug');
    expect(controller.isSignedIn, isTrue);
  });

  test('an offline start keeps the last downloaded profile and says so', () async {
    await store.write(const StoredTokens(access: 'a', refresh: 'r'));
    await cache.writeJson(AuthRepository.profileCacheKey, sampleProfile().toJson());
    api.authFailure = const Failure(FailureKind.offline, 'No connection');

    final controller = await start();

    expect(controller.status.value, SessionStatus.signedIn);
    expect(controller.notice.value, contains('last downloaded'));
  });

  test('a token the server rejects is forgotten, cache included', () async {
    await store.write(const StoredTokens(access: 'a', refresh: 'r'));
    await cache.writeJson(AuthRepository.profileCacheKey, sampleProfile().toJson());
    api.authFailure = const Failure(FailureKind.unauthorized, 'Please sign in to continue.');

    final controller = await start();

    expect(controller.status.value, SessionStatus.signedOut);
    expect(controller.profile.value, isNull);
    expect(await store.read(), isNull);
    expect(cache.readJson(AuthRepository.profileCacheKey), isNull);
  });

  test('signing in switches the app to signed-in state', () async {
    final controller = await start();
    api.session = sampleSession();

    final signedIn = await controller.signIn(' grace@udm.ac.ug ', 'Pilgrim2026road');

    expect(signedIn, isTrue);
    expect(controller.status.value, SessionStatus.signedIn);
    expect(controller.busy.value, isFalse);
    expect(controller.error.value, isEmpty);
    expect((await store.read())!.access, 'fresh-access');
  });

  test('a rejected sign-in shows the server in its own words', () async {
    final controller = await start();
    api.authFailure = const Failure(
      FailureKind.rejected,
      'Unable to log in at the moment.',
      fieldErrors: {'email': ['An account already uses this email address. Sign in instead.']},
    );

    final signedIn = await controller.signIn('grace@udm.ac.ug', 'short');

    expect(signedIn, isFalse);
    expect(controller.error.value, 'An account already uses this email address. Sign in instead.');
    expect(await store.read(), isNull);
  });

  test('saving the profile keeps what the server returned', () async {
    await store.write(const StoredTokens(access: 'a', refresh: 'r'));
    final controller = await start();

    final saved = await controller.save(controller.profile.value!.copyWith(church: 'KICA'));

    expect(saved, isTrue);
    expect(controller.profile.value?.church, 'KICA');
    expect(cache.readJson(AuthRepository.profileCacheKey)!['church'], 'KICA');
  });

  test('sign-out explains when the server could not be reached', () async {
    await store.write(const StoredTokens(access: 'a', refresh: 'r'));
    final controller = await start();
    api.authFailure = const Failure(FailureKind.offline, 'No connection');

    await controller.signOut();

    expect(controller.status.value, SessionStatus.signedOut);
    expect(controller.notice.value, contains('not revoked'));
    expect(await store.read(), isNull);
  });

  test('an expired token reported by the transport signs the app out', () async {
    await store.write(const StoredTokens(access: 'a', refresh: 'r'));
    final controller = await start();
    expect(controller.isSignedIn, isTrue);

    client.auth!.onSessionExpired!();
    await Future<void>.delayed(Duration.zero);

    expect(controller.status.value, SessionStatus.signedOut);
    expect(controller.profile.value, isNull);
    expect(controller.error.value, 'Your session expired. Sign in again to continue.');
    expect(await store.read(), isNull);
  });

  test('a profile draft keeps the fields the student did not touch', () async {
    const draft = UserProfile(
      email: 'grace@udm.ac.ug',
      displayName: 'Grace Nabukeera',
      university: 'UDM',
    );

    final edited = draft.copyWith(city: 'Kampala', interests: const ['Worship']);

    expect(edited.university, 'UDM');
    expect(edited.email, 'grace@udm.ac.ug');
    expect(edited.city, 'Kampala');
    expect(edited.interests, ['Worship']);
    expect(edited.photoUrl, isNull);
  });
}
