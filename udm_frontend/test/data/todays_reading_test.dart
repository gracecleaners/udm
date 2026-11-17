import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/data/models/todays_reading.dart';

/// Exactly what `/api/v1/home/` puts under `reading` for one student who has
/// finished two days of a thirty-day plan.
const Map<String, dynamic> dayJson = {
  'plan_title': 'Romans in a month',
  'total': 30,
  'completed': 2,
  'assignment': {
    'id': 'a-3',
    'day': 3,
    'title': 'The righteous shall live by faith',
    'reference': 'Romans 1:16-17',
    'verse_reference': 'Romans 1:17',
    'verse_text': 'The just shall live by faith.',
    'what_it_says': 'Paul is not ashamed.',
    'what_to_learn': 'Faith is what the gospel produces.',
    'completed': false,
  },
};

void main() {
  group('TodaysReading', () {
    test('reads the four authored sections the staff write', () {
      final reading = TodaysReading.fromJson(dayJson);

      expect(reading.planTitle, 'Romans in a month');
      expect(reading.total, 30);
      expect(reading.completed, 2);
      expect(reading.day.id, 'a-3');
      expect(reading.day.reference, 'Romans 1:16-17');
      expect(reading.day.verseReference, 'Romans 1:17');
      expect(reading.day.whatItSays, 'Paul is not ashamed.');
      expect(reading.day.whatToLearn, 'Faith is what the gospel produces.');
      expect(reading.day.completed, isFalse);
    });

    test('survives the cache round trip the dashboard is saved through', () {
      final reading = TodaysReading.fromJson(dayJson);
      final restored = TodaysReading.fromJson(reading.toJson());

      expect(restored.day.id, 'a-3');
      expect(restored.completed, 2);
      expect(restored.day.whatToLearn, reading.day.whatToLearn);
    });

    test('the day a student is on is the server count plus one', () {
      final reading = TodaysReading.fromJson(dayJson);

      expect(reading.number, 3);
      expect(reading.fraction, closeTo(2 / 30, 0.0001));
      expect(reading.finished, isFalse);
    });

    test('a day already read is counted, not asked for twice', () {
      final finished = TodaysReading.fromJson(dayJson).copyWith(
        completed: 3,
        day: assignment(dayJson).copyWith(completed: true),
      );

      expect(finished.number, 3);
      expect(finished.fraction, closeTo(3 / 30, 0.0001));
    });

    test('an empty plan reads as a position, not a division by zero', () {
      const empty = TodaysReading(
        planTitle: 'Nobody has published yet',
        total: 0,
        completed: 0,
        day: ReadingDay(id: 'a-1', day: 1, reference: ''),
      );

      expect(empty.fraction, 0);
      expect(empty.finished, isFalse);
      expect(empty.number, 1);
    });

    test('a count ahead of the plan still draws a full line', () {
      const ahead = TodaysReading(
        planTitle: 'Romans in a month',
        total: 30,
        completed: 34,
        day: ReadingDay(id: 'a-30', day: 30, reference: 'Romans 16', completed: true),
      );

      expect(ahead.fraction, 1);
      expect(ahead.finished, isTrue);
      expect(ahead.number, 30);
    });

    test('a day sent with nothing filled in is still a day', () {
      final day = ReadingDay.fromJson(const {'id': 'a-9', 'day': 9, 'reference': 'John 3'});

      expect(day.title, isEmpty);
      expect(day.verseText, isEmpty);
      expect(day.whatItSays, isEmpty);
      expect(day.completed, isFalse);
    });
  });
}

/// The day block on its own, as the dashboard sends it inside `assignment`.
ReadingDay assignment(Map<String, dynamic> json) =>
    ReadingDay.fromJson(json['assignment'] as Map<String, dynamic>);
