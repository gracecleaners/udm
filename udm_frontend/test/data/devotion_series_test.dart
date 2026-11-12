import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/data/models/devotion_series.dart';

/// Captured shape of `GET /api/v1/devotions/series/` and the detail route,
/// 2026-11-11. The grid answers `day_count`; only the detail carries `days`.
/// `content_version` dates the copy itself, which is what a saved row is
/// compared against when the app next reaches the server.
const Map<String, dynamic> _gridRow = {
  'id': '3f2a1c4e-5b6d-4f70-8a19-2c3d4e5f6071',
  'title': 'The Book of James',
  'description': 'Faith that shows up on Monday.',
  'cover_image_url': 'https://files.udm.ac.ug/series/james.jpg',
  'order': 1,
  'publish_at': '2026-11-01T05:00:00Z',
  'day_count': 7,
  'content_version': 23,
};

const Map<String, dynamic> _detailRow = {
  'id': '3f2a1c4e-5b6d-4f70-8a19-2c3d4e5f6071',
  'title': 'The Book of James',
  'description': 'Faith that shows up on Monday.',
  'cover_image_url': '',
  'order': 1,
  'publish_at': '2026-11-01T05:00:00Z',
  'content_version': 24,
  'days': [
    {
      'id': 'i1',
      'title': 'Who wrote this, and why',
      'day': null,
      'scripture_reference': 'James 1:1',
      'excerpt': 'A letter to the twelve tribes scattered.',
      'reading_minutes': 4,
    },
    {
      'id': 'd1',
      'title': 'Count it all joy',
      'day': 1,
      'scripture_reference': 'James 1:2-4',
      'excerpt': '',
      'reading_minutes': 5,
    },
  ],
};

void main() {
  group('DevotionSeries', () {
    test('parses a grid row exactly as the API sends it', () {
      final series = DevotionSeries.fromJson(_gridRow);

      expect(series.id, '3f2a1c4e-5b6d-4f70-8a19-2c3d4e5f6071');
      expect(series.title, 'The Book of James');
      expect(series.dayCount, 7);
      expect(series.hasCover, isTrue);
      expect(series.days, isEmpty);
      expect(series.fromCache, isFalse);
      expect(series.contentVersion, 23);
    });

    test('reads the day list and keeps an unnumbered day as the Introduction', () {
      final series = DevotionSeries.fromJson(_detailRow);

      expect(series.hasCover, isFalse);
      expect(series.days, hasLength(2));
      expect(series.days.first.isIntroduction, isTrue);
      expect(series.days.first.scriptureReference, 'James 1:1');
      expect(series.days.last.day, 1);
      expect(series.days.last.readingMinutes, 5);
    });

    test('falls back to the server default when a series has no minutes set', () {
      final series = DevotionSeries.fromJson({
        'id': 's3',
        'title': 'Christmas',
        'days': [
          {'id': 'd9', 'title': 'Light'},
        ],
      });

      expect(series.order, 1);
      expect(series.dayCount, 0);
      expect(series.days.single.readingMinutes, 5);
      expect(series.days.single.isIntroduction, isTrue);
    });

    test('survives a cache round trip with its version stamp', () {
      final stamped = DevotionSeries.fromJson(
        _gridRow,
      ).withCacheStamp(DateTime.utc(2026, 11, 10, 9), version: 12);

      final restored = DevotionSeries.fromJson(stamped.toJson());

      expect(restored.title, stamped.title);
      expect(restored.cachedAt, DateTime.utc(2026, 11, 10, 9));
      // The stamp is the whole point of the round trip: it is what tells the
      // screen its saved copy is older than the ministry's next edit.
      expect(restored.contentVersion, 12);
      expect(restored.asCached().fromCache, isTrue);
      expect(DevotionSeries.fromJson(restored.asCached().toJson()).fromCache, isTrue);
    });

    test('two letters of the title stand in for cover art', () {
      expect(DevotionSeries.fromJson(_gridRow).monogram, 'TB');
      expect(DevotionSeries(id: 's', title: 'Christmas').monogram, 'C');
      expect(DevotionSeries(id: 's', title: '   Life   of Joseph  ').monogram, 'LO');
    });
  });
}
