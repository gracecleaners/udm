import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/home_payload.dart';
import '../../data/models/resume_item.dart';
import '../../data/models/walk_summary.dart';
import '../../data/repositories/home_repository.dart';
import '../content_version/content_version_controller.dart';
import '../session/session_controller.dart';

class HomeController extends GetxController with RefetchesOnContentChange {
  HomeController(this._home, this.session);

  final HomeRepository _home;
  final SessionController session;

  final Rxn<HomePayload> payload = Rxn<HomePayload>();
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;
  final RxBool savingVerse = false.obs;
  final RxBool savingReading = false.obs;
  final RxBool statusBarUsesDarkIcons = false.obs;

  void updateStatusBarTone(double offset, double lightBackgroundStartsAt) {
    final useDarkIcons = offset >= lightBackgroundStartsAt;
    if (statusBarUsesDarkIcons.value != useDarkIcons) {
      statusBarUsesDarkIcons.value = useDarkIcons;
    }
  }

  /// Where the student stopped in the recordings, and what they have finished.
  /// Both belong to an account, so both stay empty until there is one, and a
  /// section that is empty is not drawn.
  final RxList<ResumeItem> resume = <ResumeItem>[].obs;
  final RxList<ReadHistoryRow> history = <ReadHistoryRow>[].obs;

  HomePayload? get data => payload.value;

  bool get isOfflineCopy => payload.value?.fromCache ?? false;

  /// The home card's one private action. The verse itself is public copy and
  /// reads without an account; marking it memorized belongs to a person.
  bool get verseMemorized => payload.value?.memoryVerse?.completed ?? false;

  /// Today's list ticks the items this student has already finished.
  bool isDone(String contentId) => history.any((row) => row.contentId == contentId);

  @override
  void onInit() {
    super.onInit();
    load();
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
    await loadPrivate();
  }

  /// The two account-owned rows under the public feed. A failure here is not
  /// the screen failing: the devotion and the verse still read, so the sections
  /// simply stay undrawn.
  Future<void> loadPrivate() async {
    if (!session.isSignedIn) {
      resume.clear();
      history.clear();
      return;
    }
    try {
      final started = await _home.resume();
      resume.assignAll(started);
    } on Failure {
      resume.clear();
    }
    try {
      final finished = await _home.history();
      history.assignAll(finished);
    } on Failure {
      history.clear();
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
      Get.snackbar('Saved', 'This verse is on your list to keep.');
    } on Failure catch (failure) {
      Get.snackbar('Could not save review', failure.message);
    } finally {
      savingVerse.value = false;
    }
  }

  /// Today's day of the reading plan, ticked on the account. The server counts
  /// the finished days, so the progress line moves from the number it sent plus
  /// the one the student has just done — the app keeps no streak of its own.
  Future<void> markReadingFinished() async {
    final reading = payload.value?.reading;
    if (reading == null || reading.day.completed) return;
    if (!session.isSignedIn) {
      Get.toNamed(AppRoutes.signIn);
      return;
    }
    if (savingReading.value) return;
    savingReading.value = true;
    try {
      await _home.markReadingFinished(reading.day.id);
      payload.value = payload.value?.copyWith(
        reading: reading.copyWith(
          completed: reading.completed + 1,
          day: reading.day.copyWith(completed: true),
        ),
      );
      Get.snackbar('Saved', 'Day ${reading.day.day} is on your record.');
    } on Failure catch (failure) {
      Get.snackbar('Could not save reading', failure.message);
    } finally {
      savingReading.value = false;
    }
  }

  void openDevotion(String id) =>
      Get.toNamed(AppRoutes.devotion, arguments: {RouteArgs.devotionId: id});

  void openArticle(String id) =>
      Get.toNamed(AppRoutes.article, arguments: {RouteArgs.articleId: id});

  void openTopic(String id) =>
      Get.toNamed(AppRoutes.resourceTopic, arguments: {RouteArgs.resourceTopicId: id});

  /// The day itself, in the four sections the ministry wrote for it. The plan
  /// position travels on the dashboard, so this screen needs no second call.
  void openReading() => Get.toNamed(AppRoutes.readingDay);
}
