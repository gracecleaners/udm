import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/data/providers/udm_api.dart';

/// The app's own API layer against a running backend.
///
/// Skipped unless `UDM_LIVE_API_URL` is set, so `flutter test` stays offline
/// and hermetic. It exists because the router's answers depend on keys,
/// licensing and network state that a fake cannot reproduce:
///
/// ```
/// UDM_LIVE_API_URL=http://127.0.0.1:8000/api/v1 flutter test test/data/live_bible_api_test.dart
/// ```
void main() {
  final baseUrl = Platform.environment['UDM_LIVE_API_URL'];
  final skip = baseUrl == null;
  late UdmApi api;

  setUp(() {
    if (skip) return;
    api = UdmApi(
      ApiClient(dio: Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10)))),
    );
  });

  Map<String, dynamic> source(List<Map<String, dynamic>> rows, String code) =>
      rows.firstWhere((row) => row['code'] == code);

  group('passage router', () {
    test('reports which versions this deployment can print', () async {
      final rows = await api.biblePassageSources();
      expect(rows, isNotEmpty);
      expect(source(rows, 'kjv')['text_available'], isTrue);
      expect(source(rows, 'kjv')['configured'], isTrue);
      expect(source(rows, 'niv')['text_available'], isFalse);
    }, skip: skip);

    test('serves a public-domain verse whatever the spelling', () async {
      final passage = await api.biblePassage('Jn 3:16', translation: 'kjv');
      expect(passage['reference'], 'John 3:16');
      expect(passage['translation'], 'kjv');
      expect((passage['verses'] as List).cast<Map<String, dynamic>>(), hasLength(1));
      expect(passage['deep_link_url'], startsWith('https://www.biblegateway.com/'));
      expect(passage['attribution'], isNotEmpty);
    }, skip: skip);

    test('a verse the app may not print comes back with the reason and a link', () async {
      final passage = await api.biblePassage('John 3:16', translation: 'niv');
      final fallback = passage['fallback'] as Map<String, dynamic>;
      expect(fallback['requested'], 'niv');
      expect(passage['translation'], isNot('niv'));
      expect(passage['deep_link_url'], contains('version=NIV'));
    }, skip: skip);

    test('a span keeps every verse it asked for', () async {
      final passage = await api.biblePassage('1Jn 3:16-18');
      expect((passage['verses'] as List).cast<Map<String, dynamic>>(), hasLength(3));
    }, skip: skip);

    test('the served verses carry the id a bookmark saves against', () async {
      final passage = await api.biblePassage('John 3:16', translation: 'kjv');
      final verse = (passage['verses'] as List).cast<Map<String, dynamic>>().first;
      // The key is always present; the value is only filled where this
      // deployment stores that verse, which is what the app tests before it
      // offers "Bookmark".
      expect(verse, contains('id'));
      expect(verse['id'], isA<String>());
    }, skip: skip);

    test('a reference that is not Scripture comes back as a readable refusal', () async {
      await expectLater(
        api.biblePassage('Frogs 1:1'),
        throwsA(
          isA<Failure>().having((f) => f.statusCode, 'statusCode', 400),
        ),
      );
    }, skip: skip);
  });
}
