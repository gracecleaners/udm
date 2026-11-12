import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/data/models/resource_step.dart';
import 'package:udm_frontend/app/data/models/resource_topic.dart';

/// The exact JSON `/api/v1/resources/<id>/` and `/resources/steps/<id>/` send.
const Map<String, dynamic> _topicJson = {
  'id': 'r1',
  'title': 'Receive Christ',
  'summary': 'Five short steps through what God has already done.',
  'order': 1,
  'step_count': 2,
  'content_version': 9,
  'steps': [
    {
      'id': 'i1',
      'title': 'He is near',
      'order': null,
      'scripture_reference': 'Acts 17:27-28',
      'excerpt': 'The verse that opens the guide.',
      'reading_minutes': 3,
      'video_url': '',
    },
    {
      'id': 's1',
      'title': 'All turned aside',
      'order': 1,
      'scripture_reference': 'Romans 3:10-12',
      'excerpt': '',
      'reading_minutes': 4,
      'video_url': 'https://videos.udm.ac.ug/love.mp4',
    },
  ],
};

const Map<String, dynamic> _stepJson = {
  'id': 's1',
  'title': 'All turned aside',
  'order': 1,
  'scripture_reference': 'Romans 3:10-12',
  'excerpt': 'There is no one who understands.',
  'body': 'Paul lines out the case.\n\nGrace answers it.',
  'reading_minutes': 4,
  'video_url': 'https://videos.udm.ac.ug/love.mp4',
  'topic': {'id': 'r1', 'title': 'Receive Christ', 'step_count': 2},
};

void main() {
  group('ResourceTopic', () {
    test('parses a guide with its steps in the order they were sent', () {
      final topic = ResourceTopic.fromJson(_topicJson);

      expect(topic.title, 'Receive Christ');
      expect(topic.stepCount, 2);
      expect(topic.contentVersion, 9);
      expect(topic.fromCache, isFalse);
      expect(topic.steps, hasLength(2));
      expect(topic.steps.first.isStartingPoint, isTrue);
      expect(topic.steps.last.order, 1);
      expect(topic.steps.last.hasVideo, isTrue);
      // A row of the guide page holds no passage until it is opened.
      expect(topic.steps.first.body, isEmpty);
    });

    test('survives a cache round trip and keeps the stamp', () {
      final topic = ResourceTopic.fromJson(_topicJson)
          .withCacheStamp(DateTime.utc(2026, 11, 1, 20), version: 7);
      final restored = ResourceTopic.fromJson(topic.toJson());

      expect(restored.steps, hasLength(2));
      expect(restored.steps.last.videoUrl, 'https://videos.udm.ac.ug/love.mp4');
      expect(restored.cachedAt, DateTime.utc(2026, 11, 1, 20));
      expect(restored.contentVersion, 7);
      expect(restored.asCached().fromCache, isTrue);
      expect(restored.asCached().steps, hasLength(2));
    });

    test('a guide with no steps is still readable as an empty list', () {
      final topic = ResourceTopic.fromJson({'id': 'r9', 'title': 'Faith'});

      expect(topic.steps, isEmpty);
      expect(topic.stepCount, 0);
      expect(topic.order, 1);
    });

    test('the badge takes the guide\'s own initials', () {
      expect(ResourceTopic.fromJson(_topicJson).monogram, 'RC');
      expect(const ResourceTopic(id: 'r', title: 'new believer').monogram, 'NB');
      expect(const ResourceTopic(id: 'r', title: 'Prayer').monogram, 'P');
    });
  });

  group('ResourceStep', () {
    test('parses a step page with the guide it belongs to', () {
      final step = ResourceStep.fromJson(_stepJson);

      expect(step.title, 'All turned aside');
      expect(step.order, 1);
      expect(step.body, contains('Grace answers it.'));
      expect(step.topicId, 'r1');
      expect(step.topicTitle, 'Receive Christ');
      expect(step.topicStepCount, 2);
      expect(step.isStartingPoint, isFalse);
    });

    test('a step sent without its guide keeps its own shape', () {
      final step = ResourceStep.fromJson({'id': 's2', 'title': 'Grace', 'topic': null});

      expect(step.topicId, isEmpty);
      expect(step.topicTitle, isEmpty);
      expect(step.topicStepCount, 0);
      expect(step.readingMinutes, 3);
    });

    test('round trips the guide reference a reader needs', () {
      final step = ResourceStep.fromJson(_stepJson);
      final restored = ResourceStep.fromJson(step.toJson());

      expect(restored.topicTitle, 'Receive Christ');
      expect(restored.topicStepCount, 2);
      expect(restored.videoUrl, 'https://videos.udm.ac.ug/love.mp4');
    });
  });
}
