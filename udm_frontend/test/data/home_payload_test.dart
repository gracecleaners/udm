import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/data/models/home_payload.dart';

const Map<String, dynamic> _apiJson = {
  'greeting': 'Good morning, Grace',
  'memory_verse': {
    'id': 'b1',
    'reference': 'Romans 12:2',
    'text': 'Be not conformed to this world.',
    'translation': 'kjv',
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
  'resources': [
    {'id': 'r1', 'title': 'Receive Christ', 'summary': '', 'order': 1, 'step_count': 5},
    {'id': 'r2', 'title': 'New Believer', 'order': 2, 'step_count': 5},
  ],
  'server_time': '2026-11-02T07:30:00Z',
  'content_version': 23,
};

void main() {
  group('HomePayload', () {
    test('parses the live API shape', () {
      final payload = HomePayload.fromJson(_apiJson);

      expect(payload.greeting, 'Good morning, Grace');
      expect(payload.memoryVerse?.reference, 'Romans 12:2');
      expect(payload.memoryVerse?.translationCode, 'kjv');
      expect(payload.devotion?.reflectionQuestions, hasLength(1));
      expect(payload.devotion?.readingMinutes, 5);
      expect(payload.articles.single.category, 'Bible study');
      expect(payload.resources, hasLength(2));
      expect(payload.resources.first.title, 'Receive Christ');
      expect(payload.resources.first.stepCount, 5);
      expect(payload.serverTime, DateTime.utc(2026, 11, 2, 7, 30));
      expect(payload.fromCache, isFalse);
      expect(payload.isEmpty, isFalse);
      // The payload dates its own copy, so a screen never has to guess which
      // moment its rows came from.
      expect(payload.contentVersion, 23);
    });

    test('survives a cache round trip and keeps the stamp', () {
      final payload = HomePayload.fromJson(_apiJson)
          .withCacheStamp(DateTime.utc(2026, 11, 1, 20), version: 7);
      final restored = HomePayload.fromJson(payload.toJson());

      expect(restored.devotion?.title, payload.devotion?.title);
      expect(restored.memoryVerse?.reference, 'Romans 12:2');
      expect(restored.articles.single.id, 'a1');
      expect(restored.resources, hasLength(2));
      expect(restored.resources.first.stepCount, 5);
      expect(restored.cachedAt, DateTime.utc(2026, 11, 1, 20));
      expect(restored.contentVersion, 7);
      expect(restored.asCached().fromCache, isTrue);
    });

    test('tolerates a server with nothing published yet', () {
      final payload = HomePayload.fromJson({
        'greeting': 'Good evening',
        'memory_verse': null,
        'devotion': null,
        'articles': [],
        'server_time': null,
      });

      expect(payload.isEmpty, isTrue);
      expect(payload.memoryVerse, isNull);
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
