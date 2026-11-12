import 'package:get/get.dart';

import '../../data/repositories/devotions_repository.dart';
import 'devotions_controller.dart';

class DevotionsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => DevotionsController(Get.find<DevotionsRepository>()));
  }
}
