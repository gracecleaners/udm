import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/home_payload.dart';
import '../../data/repositories/home_repository.dart';

class HomeController extends GetxController {
  HomeController(this._home);

  final HomeRepository _home;

  final Rxn<HomePayload> payload = Rxn<HomePayload>();
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  HomePayload? get data => payload.value;

  bool get isOfflineCopy => payload.value?.fromCache ?? false;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    state.value = ViewState.loading;
    failureMessage.value = '';
    try {
      final result = await _home.load();
      payload.value = result;
      state.value = result.isEmpty ? ViewState.empty : ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      state.value = ViewState.error;
    }
  }

  void openDevotion(String id) => Get.toNamed(AppRoutes.devotion, arguments: {RouteArgs.devotionId: id});

  void openArticle(String id) => Get.toNamed(AppRoutes.article, arguments: {RouteArgs.articleId: id});
}
