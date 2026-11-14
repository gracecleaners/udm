import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/models/walk_summary.dart';
import 'package:udm_frontend/app/data/repositories/home_repository.dart';
import 'package:udm_frontend/app/modules/profile/reading_history_controller.dart';
import 'package:udm_frontend/app/modules/profile/reading_history_view.dart';

import '../support/fakes.dart';

/// The screen behind the profile's Reading history row. Every row on it is the
/// account's own, taken from `/progress/`, so this file is mostly about what
/// the screen does when the account is not there.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<FakeHomeRepository> pumpHistory(
    WidgetTester tester, {
    List<ReadHistoryRow> finished = const [],
    Failure? failure,
    bool signedIn = false,
  }) async {
    final repository = FakeHomeRepository(payload: sampleHome())
      ..finished = finished
      ..failure = failure;
    Get.put<HomeRepository>(repository, permanent: true);
    // Built outside Get: a session put on the deck would start its own restore
    // and the controller would read it mid-flight as signed out.
    final session = fakeSession(signedIn: signedIn);
    Get.put(ReadingHistoryController(repository, session));
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const ReadingHistoryView()),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  ReadHistoryRow reading({
    String kind = 'devotional',
    String kindLabel = 'Devotional',
    String title = 'Trust God in Every Season',
    DateTime? on,
    String note = '',
  }) => ReadHistoryRow(
    kind: kind,
    kindLabel: kindLabel,
    contentId: 'c1',
    title: title,
    completedAt: on ?? DateTime.utc(2026, 11, 11, 9),
    note: note,
  );

  testWidgets('the days are the server\'s and the readings sit under them', (tester) async {
    final repository = await pumpHistory(tester, signedIn: true, finished: [
      reading(),
      reading(
        kind: 'article',
        kindLabel: 'Article',
        title: 'Why the Psalms still speak',
        note: 'Read with the campus fellowship.',
      ),
      reading(
        kind: 'resource_step',
        kindLabel: 'Guide step',
        title: 'Step 3 · Salt and Light',
        on: DateTime.utc(2026, 11, 9, 9),
      ),
    ]);

    expect(repository.historyCalls, 1);
    // One heading per day the server stamped, newest first.
    expect(find.text('WED, NOV 11'), findsOneWidget);
    expect(find.text('MON, NOV 9'), findsOneWidget);
    expect(find.text('Trust God in Every Season'), findsOneWidget);
    expect(find.text('Why the Psalms still speak'), findsOneWidget);
    expect(find.text('Step 3 · Salt and Light'), findsOneWidget);
    expect(find.text('Devotional'), findsOneWidget);
    expect(find.text('Guide step'), findsOneWidget);
    // The note is the student's own, so the row says one exists without
    // putting the words on a list screen.
    expect(find.text('Note kept'), findsOneWidget);
  });

  testWidgets('two readings on the same day share one heading', (tester) async {
    await pumpHistory(tester, signedIn: true, finished: [
      reading(),
      reading(title: 'A quiet morning', kindLabel: 'Article', kind: 'article'),
    ]);

    expect(find.text('WED, NOV 11'), findsOneWidget);
    expect(find.textContaining('Finished reading, most recent first.'), findsOneWidget);
  });

  testWidgets('an account that has read nothing is said so', (tester) async {
    await pumpHistory(tester, signedIn: true);

    expect(find.text('Nothing read yet'), findsOneWidget);
    expect(find.textContaining('Mark a devotional or an article as read'), findsOneWidget);
  });

  testWidgets('a visitor is not shown an empty list of someone else\'s reading', (tester) async {
    final repository = await pumpHistory(tester, finished: [reading()]);

    expect(repository.historyCalls, 0);
    expect(find.text('Nothing read yet'), findsOneWidget);
    expect(find.text('Sign in to keep a record of what you have read.'), findsOneWidget);
    expect(find.text('Trust God in Every Season'), findsNothing);
  });

  testWidgets('a first load that fails offers a working retry', (tester) async {
    final repository = await pumpHistory(
      tester,
      signedIn: true,
      failure: const Failure(FailureKind.offline, 'No connection'),
    );

    expect(find.text('We could not load this'), findsOneWidget);

    repository
      ..failure = null
      ..finished = [reading()];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.historyCalls, 2);
    expect(find.text('Trust God in Every Season'), findsOneWidget);
    expect(find.text('We could not load this'), findsNothing);
  });

  testWidgets('a refresh that fails leaves the rows already on screen', (tester) async {
    final repository = await pumpHistory(tester, signedIn: true, finished: [reading()]);
    final controller = Get.find<ReadingHistoryController>();

    repository.failure = const Failure(FailureKind.serverUnavailable, 'Unavailable.');
    await controller.load();
    await tester.pumpAndSettle();

    expect(find.text('Trust God in Every Season'), findsOneWidget);
    expect(find.text('We could not load this'), findsNothing);
  });
}
