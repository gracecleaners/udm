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
  final RxString category = 'All'.obs;
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  List<String> get categories => [
        'All',
        ...articles.map((item) => item.category.trim()).where((value) => value.isNotEmpty).toSet().toList()..sort(),
      ];

  List<Article> get visibleArticles => category.value == 'All'
      ? articles.toList()
      : articles.where((item) => item.category.trim() == category.value).toList();

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
        arguments: {RouteArgs.articleId: article.id},
      );
}
