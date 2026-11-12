import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../session/session_controller.dart';

class SignInController extends GetxController {
  SignInController(this.session);

  final SessionController session;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final RxBool revealed = false.obs;

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    session.clearMessages();
    if (await session.signIn(email.text, password.text)) Get.back();
  }

  void register() => Get.toNamed(AppRoutes.register);

  /// Public content stays reachable without an account, so signing in is never
  /// a dead end.
  void explore() => Get.back();
}

class RegisterController extends GetxController {
  RegisterController(this.session);

  final SessionController session;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController fullName = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmation = TextEditingController();
  final RxBool revealed = false.obs;
  final RxBool confirmationRevealed = false.obs;

  @override
  void onClose() {
    fullName.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    session.clearMessages();
    final created = await session.register(
      email: email.text,
      password: password.text,
      fullName: fullName.text,
    );
    if (created) {
      // The session is live the moment the server answers, so the sign-in form
      // a student may have arrived from is already stale. Land them in the app.
      Get.offAllNamed(AppRoutes.shell);
    }
  }

  void signIn() => Get.back();
}
