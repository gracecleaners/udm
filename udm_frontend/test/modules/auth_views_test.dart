import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_pages.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeAuthRepository repository;
  late ApiClient client;

  setUp(() {
    Get.testMode = true;
    repository = FakeAuthRepository(profile: sampleProfile());
    client = ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1/api/v1')), tokenStore: InMemoryTokenStore());
  });

  tearDown(() {
    Get.reset();
    client.close();
  });

  /// The app always reaches these screens from the feed, so the test does the
  /// same: a signed-in success has somewhere real to return to.
  Future<void> open(WidgetTester tester, String route) async {
    Get.put<SessionController>(SessionController(repository, client));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(name: AppRoutes.shell, page: () => const Center(child: Text('FEED'))),
          ...AppPages.pages.where((page) => page.name == AppRoutes.signIn || page.name == AppRoutes.register),
        ],
        initialRoute: AppRoutes.shell,
      ),
    );
    Get.toNamed(route);
    await tester.pumpAndSettle();
  }

  /// Both forms scroll, and the test font is much wider than the production
  /// one, so the lower fields and buttons sit below the fold. Reach them the
  /// way a student on a small phone would: scroll, then tap.
  Future<void> scrollTo(WidgetTester tester, Finder finder) => tester.ensureVisible(finder);

  Future<void> fill(WidgetTester tester, Key key, String text) async {
    final field = find.byKey(key);
    await scrollTo(tester, field);
    await tester.enterText(field, text);
  }

  Future<void> press(WidgetTester tester, Key key) async {
    final button = find.byKey(key);
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> pressText(WidgetTester tester, String label) async {
    final button = find.text(label);
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) => press(tester, const Key('udm.signIn'));

  testWidgets('an empty sign-in form is refused before any request', (tester) async {
    await open(tester, AppRoutes.signIn);

    await submit(tester);

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(repository.signInCalls, 0);
  });

  testWidgets('a malformed email is named as the problem', (tester) async {
    await open(tester, AppRoutes.signIn);

    await fill(tester, const Key('udm.emailField'), 'grace@');
    await fill(tester, const Key('udm.passwordField.Password'), 'Pilgrim2026road');
    await submit(tester);

    expect(find.text('That does not look like an email address.'), findsOneWidget);
    expect(repository.signInCalls, 0);
  });

  testWidgets('a valid sign-in returns to the feed with the session open', (tester) async {
    await open(tester, AppRoutes.signIn);

    await fill(tester, const Key('udm.emailField'), ' grace@udm.ac.ug ');
    await fill(tester, const Key('udm.passwordField.Password'), 'Pilgrim2026road');
    await submit(tester);

    expect(repository.signInCalls, 1);
    expect(find.text('FEED'), findsOneWidget);
    expect(Get.find<SessionController>().isSignedIn, isTrue);
  });

  testWidgets('what the server says about a rejected sign-in is shown', (tester) async {
    repository.failure = const Failure(
      FailureKind.rejected,
      'Unable to log in at the moment.',
      fieldErrors: {'email': ['An account already uses this email address. Sign in instead.']},
    );
    await open(tester, AppRoutes.signIn);

    await fill(tester, const Key('udm.emailField'), 'grace@udm.ac.ug');
    await fill(tester, const Key('udm.passwordField.Password'), 'Pilgrim2026road');
    await submit(tester);

    expect(find.text('An account already uses this email address. Sign in instead.'), findsOneWidget);
    expect(find.text('FEED'), findsNothing);
  });

  TextField passwordField(WidgetTester tester) => tester.widget<TextField>(
        find.descendant(of: find.byKey(const Key('udm.passwordField.Password')), matching: find.byType(TextField)),
      );

  testWidgets('passwords can be shown while typing, then hidden again', (tester) async {
    await open(tester, AppRoutes.signIn);

    await fill(tester, const Key('udm.passwordField.Password'), 'Pilgrim2026road');
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(passwordField(tester).obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(passwordField(tester).obscureText, isTrue);
  });

  testWidgets('exploring first really leaves the sign-in screen', (tester) async {
    await open(tester, AppRoutes.signIn);

    await pressText(tester, 'Explore first');

    expect(find.text('FEED'), findsOneWidget);
  });

  testWidgets('registration asks for a matching confirmation', (tester) async {
    await open(tester, AppRoutes.register);

    await fill(tester, const Key('udm.nameField'), 'Grace Nabukeera');
    await fill(tester, const Key('udm.emailField'), 'grace@udm.ac.ug');
    await fill(tester, const Key('udm.passwordField.Password'), 'Pilgrim2026road');
    await fill(tester, const Key('udm.passwordField.Confirm password'), 'Pilgrim2026');
    await press(tester, const Key('udm.register'));

    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(repository.registerCalls, 0);
  });

  testWidgets('a short password is refused by the same rule the server uses', (tester) async {
    await open(tester, AppRoutes.register);

    await fill(tester, const Key('udm.nameField'), 'Grace Nabukeera');
    await fill(tester, const Key('udm.emailField'), 'grace@udm.ac.ug');
    await fill(tester, const Key('udm.passwordField.Password'), 'pilgrim');
    await fill(tester, const Key('udm.passwordField.Confirm password'), 'pilgrim');
    await press(tester, const Key('udm.register'));

    expect(find.text('Use at least 10 characters.'), findsWidgets);
    expect(repository.registerCalls, 0);
  });

  testWidgets('a valid registration opens the session and returns to the feed', (tester) async {
    await open(tester, AppRoutes.register);

    await fill(tester, const Key('udm.nameField'), 'Grace Nabukeera');
    await fill(tester, const Key('udm.emailField'), 'grace@udm.ac.ug');
    await fill(tester, const Key('udm.passwordField.Password'), 'Pilgrim2026road');
    await fill(tester, const Key('udm.passwordField.Confirm password'), 'Pilgrim2026road');
    await press(tester, const Key('udm.register'));

    expect(repository.registerCalls, 1);
    expect(find.text('FEED'), findsOneWidget);
  });

  testWidgets('the two forms link to each other', (tester) async {
    await open(tester, AppRoutes.signIn);

    await press(tester, const Key('udm.toRegister'));
    expect(find.text('Start your journey'), findsOneWidget);

    await press(tester, const Key('udm.toSignIn'));
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
