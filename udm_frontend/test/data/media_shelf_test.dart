import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/data/models/media_collection.dart';
import 'package:udm_frontend/app/data/models/media_item.dart';

import '../support/fakes.dart';

/// The two shapes the media endpoints answer with, read exactly as the server
/// writes them: a shelf of recordings for the Learn tab, and one recording with
/// this student's own note and place in it attached.
void main() {
  group('a shelf', () {
    test('reads the list endpoint', () {
      final shelf = MediaCollection.fromJson(const {
        'id': 'c1',
        'title': 'SOMA',
        'description': 'Study, Observe, Meditate, and Apply the Scriptures.',
        'order': 1,
        'image_url': 'https://files.udm.ac.ug/media/soma.jpg',
        'item_count': 2,
        'items': [
          {'id': 'm1', 'title': 'True faith sides with God', 'duration_seconds': 940},
        ],
      });

      expect(shelf.id, 'c1');
      expect(shelf.description, 'Study, Observe, Meditate, and Apply the Scriptures.');
      expect(shelf.imageUrl, 'https://files.udm.ac.ug/media/soma.jpg');
      expect(shelf.hasArt, isTrue);
      expect(shelf.itemCount, 2);
      expect(shelf.items.single.durationLabel, '15:40');
      expect(shelf.fromCache, isFalse);
    });

    test('a row with nothing filled in is still a shelf', () {
      final shelf = MediaCollection.fromJson(const {'id': 'c9', 'title': 'Uliza'});

      // The order is the server's default and the count is what a student can
      // open, so an absent number means nothing is openable rather than zero.
      expect(shelf.order, 1);
      expect(shelf.itemCount, 0);
      expect(shelf.items, isEmpty);
      expect(shelf.hasArt, isFalse);
    });

    test('survives the cache round trip with its recordings', () {
      final shelf = sampleMediaShelves().first.withCacheStamp(
        DateTime.utc(2026, 11, 12, 8),
        version: 31,
      );

      final restored = MediaCollection.fromJson(shelf.toJson());

      expect(restored.title, 'SOMA');
      expect(restored.items.single.title, 'True faith sides with God | Hebrews 11:29-31');
      expect(restored.cachedAt, DateTime.utc(2026, 11, 12, 8));
      expect(restored.contentVersion, 31);
      // The label is this device's, not something the server ever said.
      expect(restored.fromCache, isFalse);
      expect(shelf.asCached().toJson()['from_cache'], isTrue);
    });

    test('stands on its own name when the ministry sent no art', () {
      expect(const MediaCollection(id: 'c1', title: 'SOMA').monogram, 'S');
      expect(const MediaCollection(id: 'c2', title: 'Uliza Live').monogram, 'UL');
      expect(const MediaCollection(id: 'c3', title: '  ').monogram, '');
    });
  });

  group('a recording', () {
    test('reads the detail endpoint, private half included', () {
      final item = MediaItem.fromJson(const {
        'id': 'm1',
        'title': 'True faith sides with God | Hebrews 11:29-31',
        'author': 'Edgar Karuma',
        'body': 'Moses chose the people over the palace.',
        'duration_seconds': 940,
        'youtube_video_id': 'QHJZ8pZzZfE',
        'youtube_url': 'https://youtu.be/QHJZ8pZzZfE',
        'watch': {'position_seconds': 180, 'completed': false},
        'note': {
          'text': 'Faith sides before it understands why.',
          'updated_at': '2026-11-12T15:04:00Z',
        },
        'collection': {'id': 'c1', 'title': 'SOMA', 'item_count': 2},
      });

      expect(item.resumeAt, 180);
      expect(item.watched, isFalse);
      expect(item.note, 'Faith sides before it understands why.');
      expect(item.noteUpdatedAt, DateTime.utc(2026, 11, 12, 15, 4));
      expect(item.collectionTitle, 'SOMA');
      expect(item.shareUrl, 'https://youtu.be/QHJZ8pZzZfE');
      expect(item.hasRecording, isTrue);
    });

    test('a finished recording has a completion, not a place to resume', () {
      final item = MediaItem.fromJson(const {
        'id': 'm1',
        'title': 'True faith sides with God',
        'duration_seconds': 940,
        'watch': {'position_seconds': 940, 'completed': true},
      });

      expect(item.watched, isTrue);
      expect(item.resumeAt, isNull);
    });

    test('an anonymous answer carries no private state', () {
      final item = MediaItem.fromJson(const {
        'id': 'm1',
        'title': 'True faith sides with God',
        'watched': false,
      });

      expect(item.note, isEmpty);
      expect(item.noteUpdatedAt, isNull);
      expect(item.resumeAt, isNull);
    });

    test('the runtime is stated only when the ministry knows it', () {
      expect(sampleRecording().durationLabel, '15:40');
      expect(sampleRecording().copyWith(durationSeconds: 3725).durationLabel, '1:02:05');
      // Staff who have not entered a length are not promised one.
      expect(const MediaItem(id: 'm0', title: 'No length entered').durationLabel, '');
      expect(sampleRecording().copyWith(durationSeconds: 0).durationLabel, '');
    });

    test('the address to share is the link, then the file, then nothing', () {
      expect(sampleRecording().shareUrl, 'https://youtu.be/QHJZ8pZzZfE');
      final fileOnly = sampleRecording(
        youtubeVideoId: null,
        downloadUrl: 'https://files.udm.ac.ug/media/soma-01.mp3',
      );
      expect(fileOnly.shareUrl, 'https://files.udm.ac.ug/media/soma-01.mp3');
      expect(fileOnly.hasRecording, isTrue);
      // Nothing pasted yet: the page is the write-up and offers no share.
      expect(sampleRecording(youtubeVideoId: null).shareUrl, '');
      expect(sampleRecording(youtubeVideoId: null).hasRecording, isFalse);
    });

    test('what the device saves is the public copy, never the private one', () {
      final withPrivate = sampleRecording(
        note: 'Faith sides before it understands why.',
        resumeAt: 180,
        watched: false,
      );

      final json = withPrivate.toJson();
      expect(json.containsKey('note'), isFalse);
      expect(json.containsKey('watch'), isFalse);
      // The completion mark is the student's too, so it does not travel either.
      expect(json.containsKey('watched'), isFalse);

      final restored = MediaItem.fromJson(json);
      expect(restored.note, isEmpty);
      expect(restored.resumeAt, isNull);
      expect(restored.watched, isFalse);
      // Everything a shelf row reads is still there.
      expect(restored.title, withPrivate.title);
      expect(restored.durationSeconds, 940);
      expect(restored.youtubeVideoId, 'QHJZ8pZzZfE');
      expect(restored.collectionTitle, 'SOMA');
    });
  });
}
