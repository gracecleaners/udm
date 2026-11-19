import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/new_believer_resource.dart';
import '../../data/repositories/resources_repository.dart';

class NewBelieverController extends GetxController {
  NewBelieverController(this._resources);

  final ResourcesRepository _resources;
  final RxList<NewBelieverResource> resources = <NewBelieverResource>[].obs;
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    failureMessage.value = '';
    try {
      final fresh = await _resources.newBelieverResources();
      resources.assignAll(fresh);
      state.value = fresh.isEmpty ? ViewState.empty : ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      state.value = ViewState.error;
    }
  }

  void open(NewBelieverResource resource) => Get.toNamed(
    AppRoutes.newBelieverResource,
    arguments: {RouteArgs.newBelieverResourceId: resource.id},
  );
}
