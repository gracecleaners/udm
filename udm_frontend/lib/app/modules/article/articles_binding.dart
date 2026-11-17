import 'package:get/get.dart';

import '../../data/repositories/content_repository.dart';
import 'articles_controller.dart';

class ArticlesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ArticlesController(Get.find<ContentRepository>()));
  }
}
