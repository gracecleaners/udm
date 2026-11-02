import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../data/repositories/settings_repository.dart';

/// Decides the first screen: onboarding on a fresh device, the feed afterwards.
class SplashController extends GetxController {
  SplashController(this._settings);

  final SettingsRepository _settings;

  static const Duration brandPause = Duration(milliseconds: 700);

  @override
  void onInit() {
    super.onInit();
    route();
  }

  Future<void> route() async {
    await Future<void>.delayed(brandPause);
    Get.offAllNamed(_settings.hasSeenOnboarding ? AppRoutes.shell : AppRoutes.onboarding);
  }
}
