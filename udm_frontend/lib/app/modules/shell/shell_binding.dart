import 'package:get/get.dart';

import '../../data/repositories/home_repository.dart';
import '../bible/bible_binding.dart';
import '../devotions/devotions_binding.dart';
import '../home/home_controller.dart';
import '../media/learn_binding.dart';
import '../session/session_controller.dart';
import 'shell_controller.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ShellController.new);
    Get.lazyPut(
      () => HomeController(Get.find<HomeRepository>(), Get.find<SessionController>()),
    );
    DevotionsBinding().dependencies();
    BibleBinding().dependencies();
    LearnBinding().dependencies();
  }
}
