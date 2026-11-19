import 'package:get/get.dart';

import '../../data/repositories/resources_repository.dart';
import 'new_believer_controller.dart';

class NewBelieverBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => NewBelieverController(Get.find<ResourcesRepository>()));
  }
}
