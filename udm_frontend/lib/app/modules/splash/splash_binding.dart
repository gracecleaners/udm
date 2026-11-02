import 'package:get/get.dart';

import '../../data/repositories/settings_repository.dart';
import 'splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => SplashController(Get.find<SettingsRepository>()));
}
