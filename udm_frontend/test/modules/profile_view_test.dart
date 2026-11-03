import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
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

  Future<void> openProfile(WidgetTester tester) async {
    Get.put<SessionController>(SessionController(repository, client));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(name: AppRoutes.shell, page: () => const ProfileView()),
          ...AppPages.pages.where(
            (page) => page.name == AppRoutes.signIn || page.name == AppRoutes.register,
          ),
        ],
        initialRoute: AppRoutes.shell,
      ),
    );
    await tester.pumpAndSettle();
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

  /// Inside the editor sheet, everything is built; only the tap needs the
  /// widget brought into view.
  /// The sheet scrolls its fields; the save button is pinned outside of it.
  /// Drag until the target's box is actually on screen — a widget that is
  /// merely *built* in a scroll view can still sit past the edge.
  Finder sheetScrollable() =>
      find.descendant(of: find.byType(ProfileEditorSheet), matching: find.byType(SingleChildScrollView));

  bool onScreen(WidgetTester tester, Finder target) {
    final rect = tester.getRect(target);
    return rect.top >= 0 && rect.bottom <= 600;
  }

  Future<void> revealInSheet(WidgetTester tester, Finder target) async {
    for (var attempt = 0; attempt < 12 && !onScreen(tester, target); attempt++) {
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
  });

  group('signed in', () {
    setUp(() => repository = FakeAuthRepository(profile: sampleProfile(), hasSessionValue: true));

    testWidgets('shows the server profile, not a placeholder', (tester) async {
      await openProfile(tester);

      expect(find.text('Grace Nabukeera'), findsWidgets);
      expect(find.text('grace@udm.ac.ug'), findsOneWidget);
      expect(find.textContaining('Email verification is not available'), findsOneWidget);
      expect(find.text('Not added'), findsWidgets);
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
