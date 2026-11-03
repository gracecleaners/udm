import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/network/failure.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

/// Where the student stands with the API. `unknown` only lasts the first frame;
/// the app never guesses a signed-in state before the tokens have been checked.
enum SessionStatus { unknown, restoring, signedIn, signedOut }

class SessionController extends GetxController {
  SessionController(this._auth, this._client);

  final AuthRepository _auth;
  final ApiClient _client;

  final Rx<SessionStatus> status = SessionStatus.unknown.obs;
  final Rxn<UserProfile> profile = Rxn<UserProfile>();
  final RxBool busy = false.obs;

  /// Why the last attempt failed, in the API's own words.
  final RxString error = ''.obs;

  /// A truth the student needs but that is not an error: offline copy, or a
  /// sign-out the server never saw.
  final RxString notice = ''.obs;

  bool get isSignedIn => status.value == SessionStatus.signedIn;

  bool get canBrowsePublicly => status.value != SessionStatus.restoring;

  @override
  void onInit() {
    super.onInit();
    _client.auth?.onSessionExpired = _expire;
    restore();
  }

  Future<void> restore() async {
    status.value = SessionStatus.restoring;
    profile.value = _auth.cachedProfile();
    try {
      final loaded = await _auth.restore();
      if (loaded == null) {
        status.value = SessionStatus.signedOut;
        profile.value = null;
        return;
      }
      profile.value = loaded;
      status.value = SessionStatus.signedIn;
    } on Failure catch (failure) {
      if (failure.kind == FailureKind.unauthorized) {
        await _auth.forget();
        status.value = SessionStatus.signedOut;
        profile.value = null;
        return;
      }
      // Still holding tokens: stay signed in on screen and say the profile is
      // the last downloaded one rather than pretending it is live.
      if (profile.value != null) {
        status.value = SessionStatus.signedIn;
        notice.value = 'Profile shown as last downloaded. You appear to be offline.';
      } else {
        status.value = SessionStatus.signedOut;
        error.value = failure.message;
      }
    }
  }

  Future<bool> signIn(String email, String password) =>
      _attempt(() => _auth.signIn(email: email.trim(), password: password));

  Future<bool> register({required String email, required String password, required String fullName}) => _attempt(
        () => _auth.register(email: email.trim(), password: password, fullName: fullName.trim()),
      );

  Future<bool> save(UserProfile draft) => _attempt(() => _auth.save(draft));

  Future<void> signOut() async {
    busy.value = true;
    final revoked = await _auth.signOut();
    busy.value = false;
    status.value = SessionStatus.signedOut;
    profile.value = null;
    error.value = '';
    notice.value = revoked
        ? ''
        : 'Signed out on this device. The server could not be reached, so this session was not revoked there.';
  }

  void clearMessages() {
    error.value = '';
    notice.value = '';
  }

  Future<bool> _attempt(Future<UserProfile> Function() request) async {
    busy.value = true;
    error.value = '';
    notice.value = '';
    try {
      profile.value = await request();
      status.value = SessionStatus.signedIn;
      return true;
    } on Failure catch (failure) {
      error.value = _fieldHint(failure) ?? failure.message;
      return false;
    } finally {
      busy.value = false;
    }
  }

  /// The API puts field problems in `errors`; the most useful one for a form is
  /// the first, since that is what the student filled in wrong.
  String? _fieldHint(Failure failure) {
    final messages = <String>[];
    for (final value in failure.fieldErrors.values) {
      if (value is String) messages.add(value);
      if (value is List) messages.addAll(value.whereType<String>());
    }
    return messages.isEmpty ? null : messages.first;
  }

  void _expire() {
    status.value = SessionStatus.signedOut;
    profile.value = null;
    error.value = 'Your session expired. Sign in again to continue.';
    _auth.forget();
  }
}
