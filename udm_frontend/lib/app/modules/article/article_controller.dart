import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/article.dart';
import '../../data/repositories/content_repository.dart';

class ArticleController extends GetxController {
  ArticleController(this._content, this.articleId);

  final ContentRepository _content;
  final String articleId;

  final Rxn<Article> article = Rxn<Article>();
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    state.value = ViewState.loading;
    failureMessage.value = '';
    try {
      article.value = await _content.article(articleId);
      state.value = ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      state.value = failure.kind == FailureKind.notFound ? ViewState.empty : ViewState.error;
    }
  }
}
