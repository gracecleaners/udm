import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../data/models/user_notification.dart';
import '../../data/providers/udm_api.dart';
import '../session/session_controller.dart';

class NotificationsController extends GetxController {
  NotificationsController(this._api, this._session);

  final UdmApi _api;
  final SessionController _session;
  Worker? _sessionWorker;

  final RxList<UserNotification> items = <UserNotification>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _sessionWorker = ever(_session.status, (_) {
      if (_session.isSignedIn) {
        load();
      } else {
        items.clear();
        unreadCount.value = 0;
      }
    });
    if (_session.isSignedIn) load();
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    if (!_session.isSignedIn) return;
    loading.value = true;
    error.value = '';
    try {
      final result = await _api.notifications();
      items.assignAll(result.items);
      unreadCount.value = result.unreadCount;
    } on Failure catch (failure) {
      error.value = failure.message;
    } finally {
      loading.value = false;
    }
  }

  Future<UserNotification> markRead(UserNotification item) async {
    if (item.isRead) return item;
    try {
      final updated = await _api.markNotificationRead(item.id);
      final index = items.indexWhere((entry) => entry.id == item.id);
      if (index >= 0) items[index] = updated;
      unreadCount.value = (unreadCount.value - 1).clamp(0, 1 << 30);
      return updated;
    } on Failure {
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    if (unreadCount.value == 0) return;
    await _api.markAllNotificationsRead();
    items.assignAll(items.map((item) => UserNotification(
          id: item.id,
          title: item.title,
          body: item.body,
          kind: item.kind,
          destination: item.destination,
          createdAt: item.createdAt,
          readAt: item.readAt ?? DateTime.now(),
        )));
    unreadCount.value = 0;
  }
}
