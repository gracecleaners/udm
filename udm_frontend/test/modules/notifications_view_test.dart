import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/models/user_notification.dart';
import 'package:udm_frontend/app/modules/notifications/notifications_view.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeUdmApi api;

  setUp(() {
    Get.testMode = true;
    api = FakeUdmApi();
  });
  tearDown(Get.reset);

  /// The inbox is one controller over the API's own answers, so the test wires
  /// the same pair the app does in `configureDependencies()`.
  Future<void> openInbox(WidgetTester tester, {bool signedIn = true}) async {
    final session = fakeSession(signedIn: signedIn);
    Get.put(session);
    putNotifications(api: api, session: session);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        getPages: [
          GetPage(name: '/', page: () => const NotificationsView()),
          GetPage(name: AppRoutes.community, page: () => const Center(child: Text('COMMUNITY SCREEN'))),
          GetPage(name: AppRoutes.signIn, page: () => const Center(child: Text('SIGN IN SCREEN'))),
        ],
        initialRoute: '/',
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the inbox is what the ministry sent, unread first', (tester) async {
    await openInbox(tester);

    expect(find.text('Camp service tonight'), findsOneWidget);
    expect(find.text('The worship team starts at 7 at the main hall.'), findsOneWidget);
    expect(find.text('Romans in a month is on day 3'), findsOneWidget);
    expect(api.notificationCalls, 1);
  });

  testWidgets('opening a notice marks it read and follows the ministry route', (tester) async {
    await openInbox(tester);

    await tester.tap(find.text('Camp service tonight'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.community);
    expect(api.notificationRows.first.isRead, isTrue);
  });

  testWidgets('a notice with no route of its own stays in the inbox', (tester) async {
    await openInbox(tester);

    await tester.tap(find.text('Romans in a month is on day 3'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, '/');
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('marking all read counts down from the server, not the screen', (tester) async {
    await openInbox(tester);
    expect(api.unreadCountValue, 1);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(api.unreadCountValue, 0);
    expect(api.notificationRows.every((UserNotification item) => item.isRead), isTrue);
    // Nothing left to mark, so the control is not merely styled away.
    final markAll = find.ancestor(of: find.text('Mark all read'), matching: find.byType(TextButton));
    expect(tester.widget<TextButton>(markAll).onPressed, isNull);
  });

  testWidgets('an empty inbox is caught up, not an error', (tester) async {
    api.notificationRows = [];
    api.unreadCountValue = 0;
    await openInbox(tester);

    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(find.text('New updates from UDM will appear here.'), findsOneWidget);
  });

  testWidgets('a failed inbox says so in the API\'s own words and retries', (tester) async {
    api.notificationsFailure = const Failure(FailureKind.offline, 'No connection to the UDM service.');
    await openInbox(tester);

    expect(find.text('No connection to the UDM service.'), findsOneWidget);

    api
      ..notificationsFailure = null
      ..notificationRows = sampleNotifications;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Camp service tonight'), findsOneWidget);
    expect(api.notificationCalls, 2);
  });

  testWidgets('a signed out student has no inbox to read', (tester) async {
    await openInbox(tester, signedIn: false);

    expect(find.text('Sign in to see your notifications'), findsOneWidget);
    expect(api.notificationCalls, 0);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.signIn);
  });

  testWidgets('signing out clears the badge the bell carries', (tester) async {
    final session = fakeSession(signedIn: true);
    final controller = putNotifications(api: api, session: session);
    Get.put(session);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, getPages: [GetPage(name: '/', page: () => const NotificationsView())], initialRoute: '/'),
    );
    await tester.pumpAndSettle();
    expect(controller.unreadCount.value, 1);

    session.status.value = SessionStatus.signedOut;
    await tester.pumpAndSettle();

    expect(controller.unreadCount.value, 0);
    expect(controller.items, isEmpty);
  });
}
