import 'package:get/get.dart';

import '../../core/storage/local_cache.dart';
import '../../data/providers/udm_api.dart';
import '../session/session_controller.dart';
import 'bible_controller.dart';

class BibleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => BibleController(
        Get.find<UdmApi>(),
        Get.find<LocalCache>(),
        Get.find<SessionController>(),
      ),
    );
  }
}
