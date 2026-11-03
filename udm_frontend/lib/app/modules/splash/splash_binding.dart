import 'package:get/get.dart';

import '../../data/repositories/settings_repository.dart';
import 'splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  // Eagerly, not `lazyPut`: `SplashView` is a brand screen that never looks the
  // controller up, and a lazy controller would then never be built, never run
  // `onInit`, and the app would sit on the splash for ever.
  void dependencies() {
    Get.put(SplashController(Get.find<SettingsRepository>()));
  }
}
