import 'package:get/get.dart';

import '../session/session_controller.dart';
import 'auth_controllers.dart';

class SignInBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SignInController(Get.find<SessionController>()));
  }
}

class RegisterBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => RegisterController(Get.find<SessionController>()));
  }
}
