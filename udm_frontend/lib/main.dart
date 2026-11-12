import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_bindings.dart';
import 'app/core/config/app_config.dart';
import 'app/core/routes/app_pages.dart';
import 'app/core/routes/app_routes.dart';
import 'app/core/theme/app_theme.dart';
import 'app/core/localization/app_translations.dart';
import 'app/modules/settings/app_language_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await Get.find<AppLanguageController>().restore();
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
        translations: AppTranslations(),
        locale: Get.find<AppLanguageController>().locale.value,
        fallbackLocale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        defaultTransition: Transition.fadeIn,
        transitionDuration: AppPages.transitionDuration,
      );
}
