import 'package:get/get.dart';

import '../../data/repositories/home_repository.dart';
import '../home/home_controller.dart';
import 'shell_controller.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ShellController.new);
    Get.lazyPut(() => HomeController(Get.find<HomeRepository>()));
  }
}
