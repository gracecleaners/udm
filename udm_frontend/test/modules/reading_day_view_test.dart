import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/core/widgets/app_kit.dart';
import 'package:udm_frontend/app/core/widgets/udm_widgets.dart';
import 'package:udm_frontend/app/data/models/todays_reading.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/home/home_controller.dart';
import 'package:udm_frontend/app/modules/home/reading_day_view.dart';
import 'package:udm_frontend/app/modules/shell/shell_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeHomeRepository repository;

  setUp(() {
    Get.testMode = true;
    Get.put<ContentVersionController>(FakeContentVersionController(), permanent: true);
    Get.put(ShellController());
    repository = FakeHomeRepository(payload: sampleHome());
  });
  tearDown(Get.reset);

  /// The day arrives with the dashboard, so the screen is opened exactly the
  /// way a student reaches it: from a home feed that already holds the plan.
  Future<void> openDay(WidgetTester tester, {bool signedIn = false}) async {
    Get.put(HomeController(repository, fakeSession(signedIn: signedIn)));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(name: '/', page: () => const ReadingDayView()),
          GetPage(name: AppRoutes.signIn, page: () => const Center(child: Text('SIGN IN SCREEN'))),
        ],
        initialRoute: '/',
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A day is four sections long and the list builds lazily, so a student —
  /// and a test — has to scroll to reach the last of them.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    final list = find.byType(ListView).first;
    for (var attempt = 0; attempt < 20 && finder.evaluate().isEmpty; attempt++) {
      await tester.drag(list, const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    expect(finder, findsWidgets);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  /// GetX holds a snackbar in its queue until the bar has finished closing, and
  /// the bar's timer outlives the tree; a case that saw one gives it back here.
  Future<void> dismissSnackbars(WidgetTester tester) async {
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  }

  testWidgets('the day is drawn in the four sections the ministry wrote', (tester) async {
    await openDay(tester);

    expect(find.text('ROMANS IN A MONTH · DAY 3 OF 30'), findsOneWidget);
    expect(find.text('The righteous shall live by faith'), findsOneWidget);
    expect(find.byType(Eyebrow), findsNWidgets(5));

    await scrollTo(tester, find.text('THE PASSAGE'));
    expect(find.text('Romans 1:16-17'), findsOneWidget);
    expect(find.text('Read it through before you go on.'), findsOneWidget);

    await scrollTo(tester, find.text('THE VERSE'));
    expect(find.text('The just shall live by faith.'), findsOneWidget);

    await scrollTo(tester, find.text('WHAT IT SAYS'));
    expect(find.text('Paul is not ashamed, because the gospel is the power of God.'), findsOneWidget);

    await scrollTo(tester, find.text('WHAT TO LEARN'));
    expect(find.text('Faith is what the gospel produces in you, not what you produce first.'), findsOneWidget);
  });

  testWidgets('a section the staff left blank is not drawn as an empty shape', (tester) async {
    repository.payload = sampleHome(
      reading: TodaysReading(
        planTitle: 'Romans in a month',
        total: 30,
        completed: 2,
        day: const ReadingDay(
          id: 'day-3',
          day: 3,
          title: 'The righteous shall live by faith',
          reference: 'Romans 1:16-17',
          whatItSays: 'Paul is not ashamed, because the gospel is the power of God.',
        ),
      ),
    );
    await openDay(tester);

    // The plan line, the passage and what it says: three, where the full day
    // draws five. An empty section leaves no heading and no empty card.
    expect(find.byType(Eyebrow), findsNWidgets(3));
    await scrollTo(tester, find.text('WHAT IT SAYS'));
    expect(find.text('THE VERSE'), findsNothing);
    expect(find.text('WHAT TO LEARN'), findsNothing);
  });

  testWidgets('the progress line counts the whole plan, not the phone', (tester) async {
    await openDay(tester);

    // Two days finished of thirty: the bar is the plan's own arithmetic, and
    // the sentence under it is what the server's counts allow.
    expect(find.text('2 of 30 days read.'), findsOneWidget);
    expect(tester.widget<UdmProgressBar>(find.byType(UdmProgressBar)).fraction, closeTo(2 / 30, 0.001));
  });

  testWidgets('marking the day read is saved to the account, not the device', (tester) async {
    await openDay(tester, signedIn: true);
    await scrollTo(tester, find.byKey(const Key('udm.readingDay.markRead')));

    await tester.tap(find.byKey(const Key('udm.readingDay.markRead')));
    await tester.pumpAndSettle();

    expect(repository.readingsRead, ['day-3']);
    expect(find.textContaining('Today is on your record'), findsOneWidget);
    expect(find.byKey(const Key('udm.readingDay.markRead')), findsNothing);
    expect(find.text('Saved'), findsOneWidget);

    await dismissSnackbars(tester);
  });

  testWidgets('a signed out student signs in before the day is kept', (tester) async {
    await openDay(tester);
    await scrollTo(tester, find.byKey(const Key('udm.readingDay.markRead')));

    await tester.tap(find.byKey(const Key('udm.readingDay.markRead')));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.signIn);
    expect(repository.readingsRead, isEmpty);
  });

  testWidgets('a day the server refused stays a day to read', (tester) async {
    repository.readingFailure = const Failure(FailureKind.offline, 'No connection to the UDM service.');
    await openDay(tester, signedIn: true);
    await scrollTo(tester, find.byKey(const Key('udm.readingDay.markRead')));

    await tester.tap(find.byKey(const Key('udm.readingDay.markRead')));
    await tester.pumpAndSettle();

    expect(repository.readingsRead, isEmpty);
    expect(find.text('Could not save reading'), findsOneWidget);
    expect(find.byKey(const Key('udm.readingDay.markRead')), findsOneWidget);

    await dismissSnackbars(tester);
  });

  testWidgets('the passage opens the Bible tab the student already reads', (tester) async {
    final shell = Get.find<ShellController>();
    await openDay(tester);
    await scrollTo(tester, find.byKey(const Key('udm.readingDay.openBible')));

    await tester.tap(find.byKey(const Key('udm.readingDay.openBible')));
    await tester.pumpAndSettle();

    expect(shell.tab.value, ShellController.bibleTab);
  });

  testWidgets('a plan the ministry has not published says so', (tester) async {
    repository.payload = sampleHome(withoutReading: true);
    await openDay(tester);

    expect(find.text('No reading plan yet'), findsOneWidget);
    expect(find.text('Once the ministry team publishes a daily plan it opens here.'), findsOneWidget);
    expect(find.text('THE PASSAGE'), findsNothing);
  });

  testWidgets('a finished day is not offered again', (tester) async {
    repository.payload = sampleHome(reading: sampleReading(completed: true, completedDays: 3));
    await openDay(tester, signedIn: true);

    expect(find.text('ROMANS IN A MONTH · DAY 4 OF 30'), findsOneWidget);
    expect(find.text('4 of 30 days read.'), findsOneWidget);
    await scrollTo(tester, find.textContaining('Today is on your record'));

    expect(find.byKey(const Key('udm.readingDay.markRead')), findsNothing);
  });
}
