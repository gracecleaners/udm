import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/storage/token_store.dart';
import 'package:udm_frontend/app/data/providers/udm_api.dart';

import '../support/fakes.dart';

/// Drives the real [UdmApi] against a loopback server, so attaching the bearer
/// token, refreshing it and replaying the request are tested the way the app
/// performs them rather than through a mocked transport.
void main() {
  late HttpServer server;
  late InMemoryTokenStore store;
  late ApiClient client;
  late UdmApi api;

  var refreshCalls = 0;
  var expiredEvents = 0;
  String? lastAuthorization;
  String? lastRefreshToken;
  var acceptedAccess = 'valid-access';
  var refreshStatus = 200;

  setUp(() async {
    refreshCalls = 0;
    expiredEvents = 0;
    lastAuthorization = null;
    lastRefreshToken = null;
    acceptedAccess = 'valid-access';
    refreshStatus = 200;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      switch (request.uri.path) {
        case '/api/v1/users/me/':
          lastAuthorization = request.headers.value(HttpHeaders.authorizationHeader);
          final accepted = lastAuthorization == 'Bearer $acceptedAccess';
          _respond(request, accepted ? 200 : 401, accepted ? _profileBody : _unauthorizedBody);
        case '/api/v1/auth/token/refresh/':
          refreshCalls++;
          lastRefreshToken = (await _body(request))['refresh'] as String?;
          _respond(request, refreshStatus, refreshStatus == 200 ? _freshPair : _unauthorizedBody);
        case '/api/v1/auth/token/':
          _respond(request, 401, _unauthorizedBody);
        case '/api/v1/devotions/06aba6e9-7af5-484e-aec7-ef45e0d9d4b9/':
          // Mirrors the real server, which weighs the credentials on a request
          // before it asks the view whether that request needed any: carrying a
          // bad token turns published, sign-in-free content into a 401.
          final anonymous =
              request.headers.value(HttpHeaders.authorizationHeader) == null;
          _respond(
            request,
            anonymous ? 200 : 401,
            anonymous ? _devotionalBody : _unauthorizedBody,
          );
        default:
          _respond(request, 404, _notFoundBody);
      }
    });

    store = InMemoryTokenStore(const StoredTokens(access: 'expired-access', refresh: 'stored-refresh'));
    client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api/v1', tokenStore: store);
    client.auth!.onSessionExpired = () => expiredEvents++;
    api = UdmApi(client);
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('a stored token is attached to every request', () async {
    acceptedAccess = 'expired-access';

    final profile = await api.profile();

    expect(profile.email, 'grace@udm.ac.ug');
    expect(profile.gender, 'female');
    expect(profile.yearOfStudy, 2);
    expect(lastAuthorization, 'Bearer expired-access');
    expect(refreshCalls, 0);
  });

  test('an expired access token is refreshed once, then the request is replayed', () async {
    final profile = await api.profile();

    expect(profile.displayName, 'Grace Nabukeera');
    expect(profile.interests, ['Bible study']);
    expect(refreshCalls, 1);
    expect(lastRefreshToken, 'stored-refresh');
    expect(lastAuthorization, 'Bearer valid-access');
  });

  test('the rotated pair replaces the one on the device', () async {
    await api.profile();

    final tokens = await store.read();
    expect(tokens!.access, 'valid-access');
    expect(tokens.refresh, 'rotated-refresh');
  });

  test('requests that fail together refresh only once', () async {
    final results = await Future.wait([api.profile(), api.profile(), api.profile()]);

    expect(results.map((profile) => profile.email).toSet(), {'grace@udm.ac.ug'});
    expect(refreshCalls, 1, reason: 'three 401s must not post three refreshes');
  });

  test('a rejected refresh ends the session and tells the app', () async {
    refreshStatus = 401;

    await expectLater(api.profile(), throwsA(isA<Failure>()));

    expect(await store.read(), isNull);
    expect(expiredEvents, 1);
  });

  test('a dead session does not hide content the ministry publishes free', () async {
    refreshStatus = 401;

    // The reading screens are not signed-in-only surfaces, so losing a session
    // must not be allowed to answer a devotion request with a failure.
    final devotional = await api.devotion('06aba6e9-7af5-484e-aec7-ef45e0d9d4b9');

    expect(devotional.title, 'A Heart That Listens');
    expect(devotional.body, isNotEmpty);
    expect(await store.read(), isNull);
    expect(expiredEvents, 1);
  });

  test('a refresh the server could not answer keeps the session', () async {
    refreshStatus = 503;

    await expectLater(api.profile(), throwsA(isA<Failure>()));

    expect((await store.read())?.access, 'expired-access');
    expect(expiredEvents, 0);
  });

  test('a public endpoint does not look for an expired token', () async {
    await expectLater(
      api.signIn(email: 'grace@udm.ac.ug', password: 'Pilgrim2026road'),
      throwsA(isA<Failure>()),
    );

    expect(refreshCalls, 0);
    expect(await store.read(), isNotNull);
  });
}

void _respond(HttpRequest request, int status, Map<String, dynamic> body) {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  request.response.close();
}

Future<Map<String, dynamic>> _body(HttpRequest request) async =>
    jsonDecode(await utf8.decodeStream(request)) as Map<String, dynamic>;

const Map<String, dynamic> _profileBody = {
  'email': 'grace@udm.ac.ug',
  'display_name': 'Grace Nabukeera',
  'is_email_verified': false,
  'full_name': 'Grace Nabukeera',
  'phone_number': '',
  'photo': null,
  'gender': 'female',
  'country': 'Uganda',
  'city': 'Kampala',
  'university': 'UDM',
  'campus': 'Main',
  'course': 'Food Technology',
  'year_of_study': 2,
  'church': '',
  'interests': ['Bible study'],
  'preferred_translation_code': 'kjv',
};

const Map<String, dynamic> _freshPair = {
  'access': 'valid-access',
  'refresh': 'rotated-refresh',
};

const Map<String, dynamic> _unauthorizedBody = {
  'detail': 'Given token not valid for any token type',
  'code': 'token_not_valid',
  'status': 401,
  'errors': {},
};

const Map<String, dynamic> _devotionalBody = {
  'id': '06aba6e9-7af5-484e-aec7-ef45e0d9d4b9',
  'title': 'A Heart That Listens',
  'scripture_reference': '1 Samuel 3:1-10',
  'body': 'Eli was asleep in the place the ark stood, and the lamp of God had not yet gone out.',
  'author': 'UDM Ministry Team',
  'excerpt': 'Listening is taught, not inherited.',
  'reflection_questions': ['What is God saying here?'],
  'application': 'Read this chapter slowly once before you speak to anyone about it.',
  'prayer': 'Speak, Lord; your servant is listening.',
  'memory_scripture_reference': '1 Samuel 3:9',
  'reading_minutes': 5,
  'image_url': null,
  'publish_at': '2026-11-02T06:00:00Z',
};

const Map<String, dynamic> _notFoundBody = {
  'detail': 'Not found.',
  'code': 'not_found',
  'status': 404,
  'errors': {},
};
