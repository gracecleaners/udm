import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/data/models/home_payload.dart';

const Map<String, dynamic> _apiJson = {
  'greeting': 'Good morning, Grace',
  'verse': {
    'id': 'b1',
    'reference': 'Romans 12:2',
    'text': 'Be not conformed to this world.',
    'translation_code': 'kjv',
    'attribution': 'King James Version (public domain)',
  },
  'devotion': {
    'id': 'd1',
    'title': 'A Heart That Listens',
    'scripture_reference': '1 Samuel 3:1-10',
    'body': 'Eli was half asleep.\n\nListening is taught.',
    'author': 'UDM Ministry Team',
    'excerpt': 'Samuel had the right posture.',
    'reflection_questions': ['What makes God\'s voice hard to hear?'],
    'application': 'Read the chapter once without stopping.',
    'prayer': 'Speak, Lord.',
    'memory_scripture_reference': '1 Samuel 3:9',
    'reading_minutes': 5,
    'publish_at': '2026-11-02T05:00:00Z',
  },
  'articles': [
    {
      'id': 'a1',
      'title': 'How to Study a Chapter',
      'body': 'Read once without stopping.',
      'author': 'UDM Ministry Team',
      'category': 'Bible study',
      'excerpt': '',
      'reading_minutes': 4,
      'publish_at': '2026-11-01T05:00:00Z',
    },
  ],
  'server_time': '2026-11-02T07:30:00Z',
};

void main() {
  group('HomePayload', () {
    test('parses the live API shape', () {
      final payload = HomePayload.fromJson(_apiJson);

      expect(payload.greeting, 'Good morning, Grace');
      expect(payload.verse?.reference, 'Romans 12:2');
      expect(payload.verse?.translationCode, 'kjv');
      expect(payload.devotion?.reflectionQuestions, hasLength(1));
      expect(payload.devotion?.readingMinutes, 5);
      expect(payload.articles.single.category, 'Bible study');
      expect(payload.serverTime, DateTime.utc(2026, 11, 2, 7, 30));
      expect(payload.fromCache, isFalse);
      expect(payload.isEmpty, isFalse);
    });

    test('survives a cache round trip and keeps the stamp', () {
      final payload = HomePayload.fromJson(_apiJson).withCacheStamp(DateTime.utc(2026, 11, 1, 20));
      final restored = HomePayload.fromJson(payload.toJson());

      expect(restored.devotion?.title, payload.devotion?.title);
      expect(restored.articles.single.id, 'a1');
      expect(restored.cachedAt, DateTime.utc(2026, 11, 1, 20));
      expect(restored.asCached().fromCache, isTrue);
    });

    test('tolerates a server with nothing published yet', () {
      final payload = HomePayload.fromJson({
        'greeting': 'Good evening',
        'verse': null,
        'devotion': null,
        'articles': [],
        'server_time': null,
      });

      expect(payload.isEmpty, isTrue);
      expect(payload.verse, isNull);
      expect(payload.articles, isEmpty);
    });

    test('ignores malformed list entries instead of throwing', () {
      final payload = HomePayload.fromJson({
        'greeting': 'Hi',
        'articles': [null, 3, {'id': 'ok', 'title': 'T', 'body': 'B'}],
      });

      expect(payload.articles.single.id, 'ok');
    });
  });
}
