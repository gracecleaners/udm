import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_bindings.dart';
import 'app/core/config/app_config.dart';
import 'app/core/routes/app_pages.dart';
import 'app/core/routes/app_routes.dart';
import 'app/core/theme/app_theme.dart';
import 'app/modules/settings/appearance_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const UdmApp());
}

class UdmApp extends StatelessWidget {
  const UdmApp({super.key});

  @override
  Widget build(BuildContext context) => Obx(
        // The theme is read off the controller, so an appearance change in
        // Settings repaints the app without a restart and without losing the
        // screen the student is standing on.
        () => GetMaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: Get.find<AppearanceController>().mode.value,
          initialRoute: AppRoutes.splash,
          getPages: AppPages.pages,
          defaultTransition: Transition.fadeIn,
          transitionDuration: AppPages.transitionDuration,
        ),
      );
}
