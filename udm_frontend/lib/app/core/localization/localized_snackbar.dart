import 'package:get/get.dart';

import 'app_translations.dart';

void showLocalizedSnackbar(String title, String message) =>
    Get.snackbar(
      AppTranslations.localize(title, Get.locale?.languageCode ?? 'en'),
      AppTranslations.localize(message, Get.locale?.languageCode ?? 'en'),
    );
