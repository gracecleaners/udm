import 'package:get/get.dart';
import '../settings/app_language_controller.dart';

import '../../core/localization/localized_snackbar.dart';
import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/home_payload.dart';
import '../../data/repositories/home_repository.dart';
import '../content_version/content_version_controller.dart';
import '../session/session_controller.dart';

class HomeController extends GetxController with RefetchesOnContentChange {
  HomeController(this._home, this.session);

  final HomeRepository _home;
  final SessionController session;
  Worker? _languageWorker;

  final Rxn<HomePayload> payload = Rxn<HomePayload>();
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;
  final RxBool savingVerse = false.obs;

  HomePayload? get data => payload.value;

  bool get isOfflineCopy => payload.value?.fromCache ?? false;

  /// The home card's one private action. The verse itself is public copy and
  /// reads without an account; marking it memorized belongs to a person.
  bool get verseMemorized => payload.value?.memoryVerse?.completed ?? false;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<AppLanguageController>()) {
      _languageWorker = ever(Get.find<AppLanguageController>().locale, (_) => load());
    }
    load();
  }

  @override
  void onClose() {
    _languageWorker?.dispose();
    super.onClose();
  }

  @override
  Future<void> load() async {
    state.value = ViewState.loading;
    failureMessage.value = '';
    try {
      final result = await _home.load();
      payload.value = result;
      stampLoadedContent(result.contentVersion);
      state.value = result.isEmpty ? ViewState.empty : ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      state.value = ViewState.error;
    }
  }

  /// The home card's one private action. The server records the date the verse
  /// was learned and counts the review, so the card answers with what it was
  /// told rather than with a flag the app made up.
  Future<void> markMemorized() async {
    final verse = payload.value?.memoryVerse;
    if (verse == null) return;
    if (!session.isSignedIn) {
      Get.toNamed(AppRoutes.signIn);
      return;
    }
    if (savingVerse.value) return;
    savingVerse.value = true;
    try {
      await _home.markVerseMemorized(verse.id);
      payload.value = payload.value?.copyWith(memoryVerse: verse.copyWith(completed: true));
      showLocalizedSnackbar('Saved', 'This verse is on your list to keep.');
    } on Failure catch (failure) {
      showLocalizedSnackbar('Could not save review', failure.message);
    } finally {
      savingVerse.value = false;
    }
  }

  void openDevotion(String id) => Get.toNamed(AppRoutes.devotion, arguments: {RouteArgs.devotionId: id});

  void openArticle(String id) => Get.toNamed(AppRoutes.article, arguments: {RouteArgs.articleId: id});

  void openTopic(String id) =>
      Get.toNamed(AppRoutes.resourceTopic, arguments: {RouteArgs.resourceTopicId: id});
}
