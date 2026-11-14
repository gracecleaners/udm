import 'package:udm_frontend/app/core/localization/localized_snackbar.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../settings/app_language_controller.dart';

import '../../core/network/failure.dart';
import '../../data/models/prayer_post.dart';
import '../../data/providers/udm_api.dart';
import '../session/session_controller.dart';

class CommunityController extends GetxController {
  CommunityController(this.api, this.session);

  /// The wall's filter row. `All` asks for everything this student may see;
  /// the rest are the categories the ministry itself publishes, so a tab can
  /// never be offered for a wall the server does not know.
  static const wallTabs = <String?>[null, 'prayer', 'testimony', 'encouragement'];
  static const wallLabels = ['All', 'Prayer', 'Testimonies', 'Encouragement'];

  final UdmApi api;
  final SessionController session;
  Worker? _languageWorker;
  final selectedSection = 0.obs;
  final loading = false.obs;
  final error = ''.obs;
  final universities = <Map<String, dynamic>>[].obs;
  final campuses = <Map<String, dynamic>>[].obs;
  final fellowships = <Map<String, dynamic>>[].obs;
  final groups = <Map<String, dynamic>>[].obs;
  final events = <Map<String, dynamic>>[].obs;
  final selectedWall = 0.obs;
  final loadingWall = false.obs;

  /// Every request this student may read: the published wall, their groups and
  /// their own — including the private and waiting-for-review rows, so a writer
  /// can see where their own request is standing.
  final wall = <PrayerPost>[].obs;

  /// The request whose words are open. One at a time, so a long feed stays a
  /// feed rather than turning into a page of stacked replies.
  final openPost = ''.obs;

  /// Words under a request, loaded when the card is opened rather than with
  /// the feed, which would ask for every reply on the wall.
  final comments = <String, List<PrayerComment>>{}.obs;
  final joinRequests = <String, List<Map<String, dynamic>>>{}.obs;
  final groupPrayerQueues = <String, List<Map<String, dynamic>>>{}.obs;

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

  Future<void> load() async {
    loading.value = true;
    error.value = '';
    try {
      universities.assignAll(await api.universities());
      campuses.assignAll(await api.campuses());
      fellowships.assignAll(await api.fellowships());
      groups.assignAll(await api.discipleshipGroups());
      events.assignAll(await api.events());
      await loadWall();
      joinRequests.clear();
      groupPrayerQueues.clear();
      if (session.isSignedIn) {
        for (final group in groups.where((item) => item['is_leader'] == true)) {
          final id = group['id'] as String;
          try {
            joinRequests[id] = await api.groupJoinRequests(id);
            groupPrayerQueues[id] = await api.groupPrayerQueue(id);
          } on Failure {
            // One leader-only queue should not block the rest of the community tab.
          }
        }
      }
    } on Failure catch (failure) {
      error.value = failure.message;
    } finally {
      loading.value = false;
    }
  }

  Future<void> joinGroup(Map<String, dynamic> group) async {
    if (!_requireSignIn('Sign in to request membership in a group.')) return;
    try {
      await api.requestGroupMembership(group['id'] as String);
      await load();
      showLocalizedSnackbar('Request sent', 'The group leader will review your request.');
    } on Failure catch (failure) {
      showLocalizedSnackbar('Could not request membership', failure.message);
    }
  }

  Future<void> decideMembership(String groupId, String membershipId, String status) async {
    try {
      await api.decideGroupMembership(groupId, membershipId, status);
      await load();
    } on Failure catch (failure) {
      showLocalizedSnackbar('Could not update request', failure.message);
    }
  }

  Future<void> registerForEvent(Map<String, dynamic> event) async {
    if (!_requireSignIn('Sign in to register for events.')) return;
    try {
      await api.registerForEvent(event['id'] as String);
      await load();
      showLocalizedSnackbar('Registered', 'You are on the event list.');
    } on Failure catch (failure) {
      showLocalizedSnackbar('Could not register', failure.message);
    }
  }

  Future<void> openEventLink(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      showLocalizedSnackbar('Event link unavailable', 'This event does not have a safe online link.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) showLocalizedSnackbar('Event link unavailable', 'No app could open this event.');
    } on Exception {
      showLocalizedSnackbar('Event link unavailable', 'No app could open this event.');
    }
  }

  /// Loads just the wall, which is what a filter tap, a new request or an
  /// edited reply changes. The directory, groups and events stay where they
  /// are rather than being asked for again.
  Future<void> loadWall() async {
    loadingWall.value = true;
    try {
      wall.assignAll(await api.prayerWall(category: wallTabs[selectedWall.value]));
      comments.clear();
      openPost.value = '';
    } on Failure catch (failure) {
      error.value = failure.message;
    } finally {
      loadingWall.value = false;
    }
  }

  void selectWallTab(int index) {
    selectedWall.value = index;
    loadWall();
  }

  /// "I am praying for this". The server answers with the card's own two
  /// numbers, so the wall updates in place instead of reloading.
  Future<void> toggleAffirm(PrayerPost post) async {
    if (!_requireSignIn('Sign in to stand with somebody in prayer.')) return;
    try {
      final state = await api.setPrayerAffirmation(post.id, on: !post.affirmed);
      _replace(post, post.copyWith(affirmed: state.affirmed, affirmationCount: state.count));
    } on Failure catch (failure) {
      showLocalizedSnackbar('Could not record the promise', failure.message);
    }
  }

  Future<void> toggleComments(PrayerPost post) async {
    if (openPost.value == post.id) {
      openPost.value = '';
      return;
    }
    if (!_requireSignIn('Sign in to read and write the words under a request.')) return;
    openPost.value = post.id;
    if (comments.containsKey(post.id)) return;
    try {
      comments[post.id] = await api.prayerComments(post.id);
    } on Failure catch (failure) {
      openPost.value = '';
      showLocalizedSnackbar('Could not load the words', failure.message);
    }
  }

  Future<void> addComment(PrayerPost post, String body) async {
    final words = body.trim();
    if (words.isEmpty) return;
    try {
      final comment = await api.addPrayerComment(post.id, words);
      // Newest first, which is the order the endpoint itself answers in.
      comments[post.id] = [comment, ...?comments[post.id]];
      _replace(post, post.copyWith(commentCount: post.commentCount + 1));
    } on Failure catch (failure) {
      showLocalizedSnackbar('Could not post the word', failure.message);
    }
  }

  Future<void> removeComment(PrayerPost post, String commentId) async {
    try {
      await api.removePrayerComment(post.id, commentId);
      comments[post.id] = (comments[post.id] ?? const []).where((row) => row.id != commentId).toList();
      _replace(post, post.copyWith(commentCount: post.commentCount > 0 ? post.commentCount - 1 : 0));
    } on Failure catch (failure) {
      showLocalizedSnackbar('Could not remove the word', failure.message);
    }
  }

  void _replace(PrayerPost before, PrayerPost after) {
    final index = wall.indexWhere((post) => post.id == before.id);
    if (index >= 0) wall[index] = after;
  }

  Future<void> createPrayer({
    required String body,
    required String visibility,
    String? groupId,
    required bool shareConsent,
    String category = 'prayer',
  }) async {
    if (!_requireSignIn('Sign in to save a private prayer or share with others.')) return;
    try {
      await api.createPrayerRequest(
        body: body,
        visibility: visibility,
        groupId: groupId,
        shareConsent: shareConsent,
        category: category,
      );
      await loadWall();
      showLocalizedSnackbar(
        'Prayer saved',
        visibility == 'private' ? 'Only you can see it.' : 'It is waiting for the selected reviewers.',
      );
    } on Failure catch (failure) {
      showLocalizedSnackbar('Could not save prayer', failure.message);
    }
  }

  Future<void> deletePrayer(String id) async {
    try {
      await api.deletePrayerRequest(id);
      wall.removeWhere((post) => post.id == id);
      comments.remove(id);
      if (openPost.value == id) openPost.value = '';
    } on Failure catch (failure) {
      showLocalizedSnackbar('Could not delete prayer', failure.message);
    }
  }

  Future<void> moderatePrayer(String groupId, String prayerId, String decision) async {
    try {
      await api.moderateGroupPrayer(groupId, prayerId, decision);
      await load();
    } on Failure catch (failure) {
      showLocalizedSnackbar('Could not review prayer', failure.message);
    }
  }

  bool _requireSignIn(String message) {
    if (session.isSignedIn) return true;
    showLocalizedSnackbar('Sign in required', message);
    return false;
  }
}
