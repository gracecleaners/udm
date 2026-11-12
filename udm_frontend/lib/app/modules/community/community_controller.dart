import 'package:udm_frontend/app/core/localization/localized_snackbar.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../settings/app_language_controller.dart';

import '../../core/network/failure.dart';
import '../../data/providers/udm_api.dart';
import '../session/session_controller.dart';

class CommunityController extends GetxController {
  CommunityController(this.api, this.session);

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
  final prayers = <Map<String, dynamic>>[].obs;
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
      prayers.assignAll(await api.prayerRequests());
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

  Future<void> createPrayer({
    required String body,
    required String visibility,
    String? groupId,
    required bool shareConsent,
  }) async {
    if (!_requireSignIn('Sign in to save a private prayer or share with others.')) return;
    try {
      await api.createPrayerRequest(
        body: body,
        visibility: visibility,
        groupId: groupId,
        shareConsent: shareConsent,
      );
      await load();
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
      prayers.removeWhere((prayer) => prayer['id'] == id);
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
