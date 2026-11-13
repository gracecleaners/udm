import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/core/widgets/state_view.dart';
import 'package:udm_frontend/app/core/widgets/udm_widgets.dart';

void main() {
  Future<void> at320(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Get.testMode = true;
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: Scaffold(body: widget)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('brand row in a header', (tester) async {
    await at320(
      tester,
      SizedBox(
        width: 280,
        child: Row(
          children: [
            Expanded(
              child: UdmLogo(size: 42, tagline: 'University Discipleship Mission'.toString()),
            ),
            const OfflineChip(),
          ],
        ),
      ),
    );
    debugPrint('brand=${tester.getSize(find.byType(UdmLogo))}');
    debugPrint('exception=${tester.takeException()}');
  });

  testWidgets('ghost buttons in a wrap', (tester) async {
    await at320(
      tester,
      SizedBox(
        width: 280,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            GhostButton(label: 'Open today\'s devotion', icon: Icons.book),
            GhostButton(label: 'Mark memorized', icon: Icons.verified),
          ],
        ),
      ),
    );
    debugPrint('ghost=${tester.getSize(find.byType(GhostButton).first)}');
    debugPrint('exception=${tester.takeException()}');
  });
}
