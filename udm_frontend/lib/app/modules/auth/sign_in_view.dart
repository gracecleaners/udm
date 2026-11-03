import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import 'auth_controllers.dart';
import 'auth_fields.dart';

class SignInView extends GetView<SignInController> {
  const SignInView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
          child: Centered(
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.lg),
                    child: UdmLogo(size: 40, tagline: 'Know Christ. Grow in Christ. Make Disciples.'),
                  ),
                  Text('Welcome back', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sign in to keep your reading progress and profile in step across your devices. '
                    'Nothing you write privately leaves your account.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  EmailField(controller: controller.email, autofocus: true),
                  const SizedBox(height: AppSpacing.md),
                  PasswordField(
                    controller: controller.password,
                    revealed: controller.revealed,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => controller.submit(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Obx(() => NoticeBanner(message: controller.session.error.value, tone: NoticeTone.problem)),
                  const SizedBox(height: AppSpacing.md),
                  Obx(
                    () => FilledButton(
                      key: const Key('udm.signIn'),
                      onPressed: controller.session.busy.value ? null : controller.submit,
                      child: Text(controller.session.busy.value ? 'Signing in…' : 'Sign in'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    key: const Key('udm.toRegister'),
                    onPressed: controller.register,
                    child: const Text('Create an account'),
                  ),
                  TextButton(onPressed: controller.explore, child: const Text('Explore first')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
