import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/settings_repository.dart';

class AppLanguageController extends GetxController {
  AppLanguageController(this._settings);

  final SettingsRepository _settings;
  final Rx<Locale> locale = const Locale('en').obs;

  Future<void> restore() async {
    final saved = _settings.languageCode;
    final code = saved == 'fr' ? 'fr' : 'en';
    locale.value = Locale(code);
  }

  Future<void> select(String code) async {
    if (code != 'en' && code != 'fr') return;
    await _settings.setLanguageCode(code);
    locale.value = Locale(code);
    Get.updateLocale(locale.value);
  }
}
