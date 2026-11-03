import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/content_kind.dart';
import '../../data/models/devotional.dart';
import '../../data/repositories/content_repository.dart';
import '../reader/reading_progress.dart';
import '../session/session_controller.dart';

class DevotionController extends GetxController with TracksReadingProgress {
  DevotionController(this._content, this._session, this.devotionalId);

  final ContentRepository _content;
  final SessionController _session;
  final String devotionalId;

  @override
  ContentRepository get content => _content;

  @override
  SessionController get session => _session;

  @override
  ContentKind get progressKind => ContentKind.devotional;

  @override
  String get progressId => devotionalId;

  final Rxn<Devotional> devotional = Rxn<Devotional>();
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
      devotional.value = await _content.devotional(devotionalId);
      state.value = ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      state.value = failure.kind == FailureKind.notFound ? ViewState.empty : ViewState.error;
    }
  }
}
