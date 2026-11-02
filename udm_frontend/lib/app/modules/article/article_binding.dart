import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../data/repositories/content_repository.dart';
import 'article_controller.dart';

class ArticleBinding extends Bindings {
  @override
  void dependencies() {
    final arguments = Get.arguments;
    final id = arguments is Map<String, dynamic> ? arguments[RouteArgs.articleId] as String : '';
    Get.lazyPut(() => ArticleController(Get.find<ContentRepository>(), id));
  }
}
