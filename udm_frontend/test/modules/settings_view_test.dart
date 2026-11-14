import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/core/widgets/app_kit.dart';
import 'package:udm_frontend/app/data/repositories/settings_repository.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/settings/app_language_controller.dart';
import 'package:udm_frontend/app/modules/settings/appearance_controller.dart';
import 'package:udm_frontend/app/modules/settings/reading_size_sheet.dart';
import 'package:udm_frontend/app/modules/settings/settings_view.dart';

import '../support/fakes.dart';

/// Settings is the device's own screen: nothing here is sent to the ministry,
/// and nothing here is invented for the mockup. These tests hold both lines.
void main() {
  late SharedPreferences prefs;

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(Get.reset);

  Future<AppearanceController> pumpSettings(WidgetTester tester) async {
    prefs = await SharedPreferences.getInstance();
    final settings = SettingsRepository(LocalCache(prefs));
    final appearance = Get.put(AppearanceController(settings), permanent: true);
    Get.put(AppLanguageController(settings), permanent: true);
    Get.put<ContentVersionController>(FakeContentVersionController(), permanent: true);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const SettingsView()),
    );
    await tester.pumpAndSettle();
    return appearance;
  }

  /// The groups run past the fold, and the list will not build what is not on
  /// screen, so a target is dragged into view before it is read or tapped.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (var attempt = 0; attempt < 12 && target.evaluate().isEmpty; attempt++) {
      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapSetting(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// The tick a group puts on the choice this device is actually on.
  Finder checkOn(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
    matching: find.byIcon(AppIcons.check),
  );

  testWidgets('the device choices are grouped in the order the app keeps them', (tester) async {
    await pumpSettings(tester);

    expect(find.text('How the app looks and reads on this device.'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    // A student who never opened this screen still follows the phone.
    expect(checkOn('Follow the phone'), findsOneWidget);
    expect(checkOn('Light'), findsNothing);

    // Read on the way down: a list past the fold drops what it has scrolled
    // out of view, so each group is checked while it is still on screen.
    await reveal(tester, find.text('READING'));
    expect(find.text('Text size'), findsOneWidget);

    await reveal(tester, find.text('LANGUAGE'));
    expect(find.text('English'), findsOneWidget);

    await reveal(tester, find.text('ABOUT UDM'));
    expect(find.text('Content on this device'), findsOneWidget);

    await reveal(tester, find.text('HELP'));
    expect(find.textContaining('Marking a reading finished writes to your account'), findsOneWidget);
  });

  testWidgets('choosing the dark changes this run and is kept for the next', (tester) async {
    final appearance = await pumpSettings(tester);

    await tapSetting(tester, find.text('Dark'));

    expect(appearance.mode.value, ThemeMode.dark);
    expect(checkOn('Dark'), findsOneWidget);
    expect(checkOn('Follow the phone'), findsNothing);
    expect(prefs.getString(SettingsRepository.themeModeKey), 'dark');
  });

  testWidgets('the reading size opens the sheet the verses were proofed at', (tester) async {
    final appearance = await pumpSettings(tester);

    await tapSetting(tester, find.text('Text size'));
    expect(find.byType(ReadingSizeSheet), findsOneWidget);
    expect(find.text('READING SIZE'), findsOneWidget);
    // The middle step is the one the design was drawn at.
    expect(appearance.readingSize.label, 'Medium');
    expect(find.text('For God so loved the world, that he gave his only begotten Son…'), findsNWidgets(4));

    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();

    expect(appearance.readingScale.value, 1.15);
    expect(prefs.getString(SettingsRepository.readingScaleKey), '1.15');
    // The reading styles take their size from the token this choice writes, so
    // prose anywhere in the app is sized by it without asking for the setting.
    expect(AppTypography.readingScale, 1.15);

    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ReadingSizeSheet), findsNothing);
    expect(find.text('Large'), findsOneWidget);
  });

  testWidgets('the language is the one choice that reaches the server', (tester) async {
    await pumpSettings(tester);
    final language = Get.find<AppLanguageController>();

    await reveal(tester, find.text('Français'));
    // Switching the language rebuilds the app with the new one, and that
    // reassembly needs the real event loop rather than the test clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('Français'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    expect(language.locale.value, const Locale('fr'));
    expect(prefs.getString(SettingsRepository.languageKey), 'fr');
    expect(Get.locale, const Locale('fr'));
  });

  testWidgets('about names the published copy this device is reading', (tester) async {
    await pumpSettings(tester);

    await reveal(tester, find.text('ABOUT UDM'));
    expect(find.textContaining('has not heard from the UDM service'), findsOneWidget);

    (Get.find<ContentVersionController>() as FakeContentVersionController).emit(12);
    await tester.pumpAndSettle();

    expect(find.textContaining('published at version 12'), findsOneWidget);
  });

  testWidgets('the help says what this build does, and no switch is decoration', (tester) async {
    await pumpSettings(tester);

    // No push is sent and no cache size is measured, so neither switch the
    // showcase drew is put on screen without an endpoint behind it.
    expect(find.textContaining('Notifications'), findsNothing);
    expect(find.textContaining('Data usage'), findsNothing);

    await reveal(tester, find.text('HELP'));
    expect(find.textContaining('read without an account'), findsOneWidget);
    expect(find.textContaining('keeps its last server copy'), findsOneWidget);
    expect(find.textContaining('goes to a leader'), findsOneWidget);
  });
}
