import 'package:get/get.dart';

import '../../data/repositories/home_repository.dart';
import '../session/session_controller.dart';
import 'reading_history_controller.dart';

class ReadingHistoryBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(
    () => ReadingHistoryController(
      Get.find<HomeRepository>(),
      Get.find<SessionController>(),
    ),
  );
}
