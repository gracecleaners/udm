import 'package:get/get.dart';

import '../../data/repositories/settings_repository.dart';
import 'onboarding_controller.dart';

class OnboardingBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => OnboardingController(Get.find<SettingsRepository>()));
}
