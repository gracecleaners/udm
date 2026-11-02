import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_bindings.dart';
import 'app/core/config/app_config.dart';
import 'app/core/routes/app_pages.dart';
import 'app/core/routes/app_routes.dart';
import 'app/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const UdmApp());
}

class UdmApp extends StatelessWidget {
  const UdmApp({super.key});

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        defaultTransition: Transition.fadeIn,
        transitionDuration: AppPages.transitionDuration,
      );
}
