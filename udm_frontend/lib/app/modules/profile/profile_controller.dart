import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../data/models/walk_summary.dart';
import '../../data/repositories/home_repository.dart';
import '../session/session_controller.dart';

/// The numbers a student keeps about their own walk, as the server counts them.
///
/// These are the profile's tiles, and every one of them is an account's: an
/// anonymous visitor has finished nothing the server can name, so nothing is
/// offered to them. The app never keeps a copy — a shared family phone should
/// not show last week's reader how far this one has come.
class ProfileController extends GetxController {
  ProfileController(this._home, this.session);

  final HomeRepository _home;
  final SessionController session;

  final Rxn<WalkSummary> summary = Rxn<WalkSummary>();
  final RxBool loadingPrivate = false.obs;
  Worker? _sessionWorker;

  bool get hasNumbers => summary.value != null;

  @override
  void onInit() {
    super.onInit();
    // Signing in is the moment these numbers start to exist, and signing out
    // is the moment they stop belonging to this phone.
    _sessionWorker = ever(session.status, (_) => load());
    load();
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    if (!session.isSignedIn) {
      summary.value = null;
      return;
    }
    loadingPrivate.value = true;
    try {
      summary.value = await _home.summary();
    } on Failure {
      // A tile that would print a number the server has not given is a tile
      // left off, not one filled with a guess.
      summary.value = null;
    } finally {
      loadingPrivate.value = false;
    }
  }
}
