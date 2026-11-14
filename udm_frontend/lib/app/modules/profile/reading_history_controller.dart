import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/walk_summary.dart';
import '../../data/repositories/home_repository.dart';
import '../session/session_controller.dart';

/// What this student has finished, newest first.
///
/// The rows are the account's, taken straight from the server each time the
/// screen opens. Nothing here is cached, so a shared phone never shows one
/// student another student's reading.
class ReadingHistoryController extends GetxController {
  ReadingHistoryController(this._home, this.session);

  final HomeRepository _home;
  final SessionController session;

  final RxList<ReadHistoryRow> rows = <ReadHistoryRow>[].obs;
  final Rx<ViewState> state = ViewState.loading.obs;
  final RxString failureMessage = ''.obs;

  /// Grouped for the screen: one heading per day, the server's own order kept
  /// inside it. The app does not sort a student's history into a shape the
  /// ministry did not write.
  List<({DateTime day, List<ReadHistoryRow> rows})> get days {
    final groups = <DateTime, List<ReadHistoryRow>>{};
    for (final row in rows) {
      final finished = row.completedAt.toLocal();
      final day = DateTime(finished.year, finished.month, finished.day);
      groups.putIfAbsent(day, () => []).add(row);
    }
    return [for (final entry in groups.entries) (day: entry.key, rows: entry.value)];
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (!session.isSignedIn) {
      // The screen is reached from an account row, so a visitor who lands here
      // by accident is told what it needs rather than shown an empty list.
      rows.clear();
      state.value = ViewState.empty;
      return;
    }
    if (rows.isEmpty) state.value = ViewState.loading;
    failureMessage.value = '';
    try {
      final finished = await _home.history();
      rows.assignAll(finished);
      state.value = finished.isEmpty ? ViewState.empty : ViewState.ready;
    } on Failure catch (failure) {
      failureMessage.value = failure.message;
      // Rows already on screen are this student's own reading, so a dropped
      // connection does not take the list away.
      state.value = rows.isEmpty ? ViewState.error : ViewState.ready;
    }
  }
}
