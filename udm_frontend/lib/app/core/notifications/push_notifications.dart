import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../../data/providers/udm_api.dart';
import '../../modules/session/session_controller.dart';

/// How this device reaches Firebase, or explains quietly why it cannot.
///
/// A push is only a doorbell. The ministry's inbox behind
/// `GET /api/v1/notifications/` is the record, so every step here is allowed to
/// fail: a build with no Firebase configuration, a student who refused the
/// permission prompt, or a network that will not carry the token registration
/// all leave the inbox and the bell on home working exactly as before.
///
/// Nothing is asked of the student before they sign in. A push can only reach
/// an account, so a device that holds no account holds no token either.
class PushNotifications extends GetxService {
  PushNotifications(this._api, this._session);

  final UdmApi _api;
  final SessionController _session;

  Worker? _sessionWorker;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;

  /// The token this installation last handed the ministry, so a refresh that
  /// repeats itself never sends a second registration.
  String? _token;

  /// The token the ministry is currently holding for this account, if any.
  String? _registeredToken;

  /// Set once Firebase answers on this device. Desktop runs and unsigned builds
  /// leave it false, and the app simply never mentions push.
  bool get available => _available;
  bool _available = false;

  @override
  void onInit() {
    super.onInit();
    unawaited(_start());
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.onClose();
  }

  Future<void> _start() async {
    if (_platform == null) return;
    try {
      await Firebase.initializeApp();
      _available = true;
      final messaging = FirebaseMessaging.instance;
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_show);
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_open);
      _sessionWorker = ever(_session.status, _onSession);
      final launched = await messaging.getInitialMessage();
      if (launched != null) _open(launched);
      await _onSession(_session.status.value);
    } catch (_) {
      // No google-services.json / GoogleService-Info.plist in this build, or no
      // SDK on this platform. There is nothing to tell the student: the inbox
      // lives on the home bell either way.
      _available = false;
    }
  }

  Future<void> _onSession(SessionStatus status) async {
    if (status == SessionStatus.signedIn) await _enable();
    if (status == SessionStatus.signedOut) await _disable();
  }

  /// Permission, token, registration — and the registration is repeated after a
  /// sign-out, because the ministry puts one row per token and moves it to
  /// whichever account holds the phone.
  Future<void> _enable() async {
    if (!_available) return;
    final messaging = FirebaseMessaging.instance;
    if (_token == null) {
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      _token = await messaging.getToken();
      _tokenSubscription = messaging.onTokenRefresh.listen((next) {
        _token = next;
        unawaited(_register(next));
      });
    }
    await _register(_token);
  }

  Future<void> _register(String? token) async {
    final platform = _platform;
    if (!_available || token == null || token.isEmpty || platform == null) return;
    if (!_session.isSignedIn) return;
    if (token == _registeredToken) return;
    try {
      await _api.registerNotificationDevice(token: token, platform: platform);
      _registeredToken = token;
    } catch (_) {
      // Offline: retried at the next sign-in, and the inbox still pulls.
    }
  }

  Future<void> _disable() async {
    final token = _registeredToken;
    _registeredToken = null;
    if (token != null) await _forget(token);
  }

  Future<void> _forget(String token) async {
    try {
      await _api.unregisterNotificationDevice(token);
    } catch (_) {
      // The row ages out; a student who signs back in re-registers it.
    }
  }

  void _show(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    Get.snackbar(
      notification.title ?? 'From your ministry team',
      notification.body ?? '',
      onTap: (_) => _open(message),
    );
  }

  /// A tap lands on the inbox rather than the notice's own route: that is the
  /// one screen that marks it read, and its rows already deep link.
  void _open(RemoteMessage message) {
    if (Get.currentRoute == AppRoutes.notifications) return;
    Get.toNamed(AppRoutes.notifications);
  }

  /// Android and iOS only, because those are the two platforms the ministry's
  /// `NotificationDevice` takes a token for.
  String? get _platform => switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => null,
      };
}
