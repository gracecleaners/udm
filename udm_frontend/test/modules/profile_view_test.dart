import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/data/models/walk_summary.dart';
import 'package:udm_frontend/app/data/repositories/home_repository.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/profile/profile_controller.dart';
import 'package:udm_frontend/app/modules/shell/shell_controller.dart';
import 'package:udm_frontend/app/core/routes/app_pages.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/modules/profile/profile_view.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeAuthRepository repository;
  late ApiClient client;

  setUp(() {
    Get.testMode = true;
    client = ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1/api/v1')), tokenStore: InMemoryTokenStore());
  });

  tearDown(() {
    Get.reset();
    client.close();
  });

  Future<FakeHomeRepository> openProfile(
    WidgetTester tester, {
    WalkSummary numbers = const WalkSummary(),
    Failure? summaryFailure,
  }) async {
    Get.put<SessionController>(SessionController(repository, client));
    // The two controllers the shell registers around this tab: the student's
    // own numbers, and the bar the bookmarks row moves.
    final home = FakeHomeRepository(payload: sampleHome())
      ..numbers = numbers
      ..summaryFailure = summaryFailure;
    Get.put<HomeRepository>(home, permanent: true);
    // Moving to the Bible tab is a content-version poll, so the bar and the
    // stamp it looks up both have to be on the deck.
    Get.put<ContentVersionController>(FakeContentVersionController(), permanent: true);
    Get.put(ShellController());
    Get.put(ProfileController(home, Get.find<SessionController>()));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(name: AppRoutes.shell, page: () => const ProfileView()),
          ...AppPages.pages.where(
            (page) => page.name == AppRoutes.signIn || page.name == AppRoutes.register,
          ),
          // The three screens the account rows lead to, as stubs: this file is
          // about the rows, and each destination has its own test.
          GetPage(
            name: AppRoutes.readingHistory,
            page: () => const Center(child: Text('HISTORY SCREEN')),
          ),
          GetPage(name: AppRoutes.courses, page: () => const Center(child: Text('COURSES SCREEN'))),
          GetPage(name: AppRoutes.settings, page: () => const Center(child: Text('SETTINGS SCREEN'))),
        ],
        initialRoute: AppRoutes.shell,
      ),
    );
    await tester.pumpAndSettle();
    return home;
  }

  /// The profile body is a lazy list, and the test font renders every row
  /// taller than production does, so buttons and rows start below the fold.
  /// `step` says which way to drag: negative reveals what is below, positive
  /// what is above.
  Future<void> scrollTo(WidgetTester tester, Finder target, {Offset step = const Offset(0, -100)}) async {
    await tester.dragUntilVisible(target, find.byType(ListView), step);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapBody(WidgetTester tester, Key key) async {
    final button = find.byKey(key);
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  /// The same reveal-then-tap for a target named by its text — the account rows
  /// carry no keys of their own, because there is only ever one of each.
  Future<void> tapRow(WidgetTester tester, String label) async {
    final row = find.text(label);
    await scrollTo(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  /// Inside the editor sheet, everything is built; only the tap needs the
  /// widget brought into view.
  /// The sheet scrolls its fields; the save button is pinned outside of it.
  /// Drag until the target's box is actually on screen — a widget that is
  /// merely *built* in a scroll view can still sit past the edge.
  /// Only the vertical scroller counts: the gender row carries its own
  /// horizontal one, and dragging that never reveals a field.
  Finder sheetScrollable() => find.descendant(
        of: find.byType(ProfileEditorSheet),
        matching: find.byWidgetPredicate(
          (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.vertical,
        ),
      );

  /// A target only counts as reachable once it is inside the sheet's own
  /// viewport: the screen is 600px tall but the save row is pinned below the
  /// scroller, so a widget at the foot of the screen can still be covered.
  bool onScreen(WidgetTester tester, Finder target) {
    final viewport = tester.getRect(sheetScrollable());
    final rect = tester.getRect(target);
    return rect.top >= viewport.top && rect.bottom <= viewport.bottom;
  }

  Future<void> revealInSheet(WidgetTester tester, Finder target) async {
    for (var attempt = 0; attempt < 16 && !onScreen(tester, target); attempt++) {
      await tester.drag(sheetScrollable(), const Offset(0, -120));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapInSheet(WidgetTester tester, Key key) async {
    final button = find.byKey(key);
    await revealInSheet(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> fillInSheet(WidgetTester tester, Key key, String text) async {
    final field = find.byKey(key);
    await revealInSheet(tester, field);
    await tester.enterText(field, text);
  }

  group('signed out', () {
    setUp(() => repository = FakeAuthRepository(profile: sampleProfile()));

    testWidgets('the tab offers sign-in but never blocks browsing', (tester) async {
      await openProfile(tester);

      expect(find.text('Not signed in'), findsOneWidget);
      expect(find.textContaining('Devotions, verses and articles stay readable'), findsOneWidget);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('create an account opens the registration form', (tester) async {
      await openProfile(tester);

      await tester.tap(find.byKey(const Key('udm.registerFromProfile')));
      await tester.pumpAndSettle();

      expect(find.text('Start your journey'), findsOneWidget);
    });

    testWidgets('never asks the service for an account\'s numbers', (tester) async {
      final home = await openProfile(
        tester,
        numbers: const WalkSummary(dayStreak: 24, devotionalsCompleted: 12),
      );

      expect(home.summaryCalls, 0);
      expect(find.text('day streak'), findsNothing);
    });
  });

  group('signed in', () {
    setUp(() => repository = FakeAuthRepository(profile: sampleProfile(), hasSessionValue: true));

    testWidgets('shows the server profile, not a placeholder', (tester) async {
      await openProfile(tester);

      expect(find.text('Grace Nabukeera'), findsWidgets);
      expect(find.text('grace@udm.ac.ug'), findsOneWidget);
      expect(find.textContaining('Email verification is not available'), findsOneWidget);
      // The details now sit below the numbers and the account rows, and a
      // lazy list has not built what the student has not scrolled to. The
      // scroll stops on the group's own heading, which is named once.
      await scrollTo(tester, find.text('University'));
      expect(find.text('Not added'), findsWidgets);
    });

    testWidgets('prints the counts the service keeps about this walk', (tester) async {
      final home = await openProfile(
        tester,
        numbers: const WalkSummary(
          dayStreak: 24,
          devotionalsCompleted: 12,
          articlesCompleted: 1,
          guidesCompleted: 2,
          stepsCompleted: 9,
        ),
      );

      expect(home.summaryCalls, 1);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('day streak'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.text('devotionals read'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('guides finished'), findsOneWidget);
    });

    testWidgets('a student who has finished nothing is told so', (tester) async {
      await openProfile(tester);

      expect(find.text('0'), findsNWidgets(3));
      expect(find.text('guides finished'), findsOneWidget);
    });

    testWidgets('one finished guide is not pluralised past the server', (tester) async {
      await openProfile(tester, numbers: const WalkSummary(guidesCompleted: 1, devotionalsCompleted: 1));

      expect(find.text('guide finished'), findsOneWidget);
      expect(find.text('devotional read'), findsOneWidget);
    });

    testWidgets('no numbers from the service means no tiles, not guessed ones', (tester) async {
      await openProfile(
        tester,
        summaryFailure: const Failure(FailureKind.offline, 'No connection to the UDM service.'),
      );

      expect(find.text('day streak'), findsNothing);
    });

    testWidgets('the account rows reach the screens they name', (tester) async {
      await openProfile(tester);

      await tapRow(tester, 'Reading history');
      expect(find.text('HISTORY SCREEN'), findsOneWidget);
      Get.back();
      await tester.pumpAndSettle();

      await tapRow(tester, 'My courses');
      expect(find.text('COURSES SCREEN'), findsOneWidget);
      Get.back();
      await tester.pumpAndSettle();

      await tapRow(tester, 'Settings');
      expect(find.text('SETTINGS SCREEN'), findsOneWidget);
      Get.back();
      await tester.pumpAndSettle();
    });

    testWidgets('bookmarks move the bar to the Bible, where they are read', (tester) async {
      await openProfile(tester);

      await tapRow(tester, 'My bookmarks');

      expect(Get.find<ShellController>().tab.value, ShellController.bibleTab);
      expect(find.text('HISTORY SCREEN'), findsNothing);
    });

    testWidgets('editing saves through the session and shows the new value', (tester) async {
      await openProfile(tester);

      await tapBody(tester, const Key('udm.editProfile'));

      await fillInSheet(tester, const Key('udm.field.university'), 'Uganda Martyrs University');
      await fillInSheet(tester, const Key('udm.field.year_of_study'), '4');
      await tapInSheet(tester, const Key('udm.saveProfile'));

      expect(repository.savedChanges!['university'], 'Uganda Martyrs University');
      expect(repository.savedChanges!['year_of_study'], 4);
      expect(repository.savedChanges!.containsKey('email'), isFalse);

      await scrollTo(tester, find.text('Uganda Martyrs University'), step: const Offset(0, 120));
      expect(find.text('Uganda Martyrs University'), findsOneWidget);
      expect(find.text('Year 4'), findsOneWidget);
    });

    testWidgets('adding an interest sends it as a label', (tester) async {
      await openProfile(tester);
      await tapBody(tester, const Key('udm.editProfile'));

      await fillInSheet(tester, const Key('udm.field.interest'), 'Worship');
      await tapInSheet(tester, const Key('udm.addInterest'));
      await tapInSheet(tester, const Key('udm.saveProfile'));

      expect(repository.savedChanges!['interests'], ['Worship']);
      expect(find.byKey(const Key('udm.field.interest')), findsNothing);
    });

    testWidgets('a year outside the server range is refused on the device', (tester) async {
      await openProfile(tester);
      await tapBody(tester, const Key('udm.editProfile'));

      await fillInSheet(tester, const Key('udm.field.year_of_study'), '40');
      await tapInSheet(tester, const Key('udm.saveProfile'));

      expect(find.text('Between 1 and 13.'), findsOneWidget);
      expect(repository.savedChanges, isNull);
      expect(find.byKey(const Key('udm.saveProfile')), findsOneWidget);
    });

    testWidgets('sign-out asks first, then ends the session', (tester) async {
      await openProfile(tester);

      await tapBody(tester, const Key('udm.signOut'));
      await tester.tap(find.byKey(const Key('udm.confirmSignOut')));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(find.text('Not signed in'), findsOneWidget);
    });

    testWidgets('an offline sign-out says the server never saw it', (tester) async {
      repository.revokeSucceeds = false;
      await openProfile(tester);

      await tapBody(tester, const Key('udm.signOut'));
      await tester.tap(find.byKey(const Key('udm.confirmSignOut')));
      await tester.pumpAndSettle();

      expect(find.textContaining('was not revoked there'), findsOneWidget);
    });

    testWidgets('canceling the sign-out dialog keeps the session', (tester) async {
      await openProfile(tester);

      await tester.tap(find.byKey(const Key('udm.signOutAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 0);
      expect(find.text('Grace Nabukeera'), findsWidgets);
    });
  });
}
