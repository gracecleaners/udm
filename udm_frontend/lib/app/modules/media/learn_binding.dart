import 'package:get/get.dart';

import '../../data/repositories/media_repository.dart';
import '../session/session_controller.dart';
import 'learn_controller.dart';

/// Registered by the shell: the Learn tab is one of the five surfaces a
/// student lands on, not a page pushed onto the stack.
class LearnBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => LearnController(Get.find<MediaRepository>(), Get.find<SessionController>()),
    );
  }
}
