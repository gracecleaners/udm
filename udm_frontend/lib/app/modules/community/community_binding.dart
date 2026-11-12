import 'package:get/get.dart';

import '../../data/providers/udm_api.dart';
import '../session/session_controller.dart';
import 'community_controller.dart';

class CommunityBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CommunityController(Get.find<UdmApi>(), Get.find<SessionController>()),
    );
  }
}
