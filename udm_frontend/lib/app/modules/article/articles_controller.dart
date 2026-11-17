import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/article.dart';
import '../../data/repositories/content_repository.dart';

class ArticlesController extends GetxController {
  ArticlesController(this._content);

  final ContentRepository _content;
  final RxList<Article> articles = <Article>[].obs;
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (articles.isEmpty) state.value = ViewState.loading;
    failureMessage.value = '';
    try {
      articles.assignAll(await _content.articles());
      state.value = articles.isEmpty ? ViewState.empty : ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      if (articles.isEmpty) state.value = ViewState.error;
    }
  }

  void open(Article article) => Get.toNamed(
        AppRoutes.article,
        arguments: {'articleId': article.id},
      );
}
