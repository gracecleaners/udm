import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_view.dart';
import 'auth_controllers.dart';
import 'auth_fields.dart';
import 'validators.dart';

class RegisterView extends GetView<RegisterController> {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
          child: Centered(
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Start your journey', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'An email address and a password are enough. Your campus details, reading '
                    'progress and reflections are saved to your own account.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NameField(controller: controller.fullName, autofocus: true),
                  const SizedBox(height: AppSpacing.md),
                  EmailField(controller: controller.email),
                  const SizedBox(height: AppSpacing.md),
                  PasswordField(
                    controller: controller.password,
                    revealed: controller.revealed,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'At least ${AuthValidators.minimumPasswordLength} characters, not a common word.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PasswordField(
                    controller: controller.confirmation,
                    revealed: controller.confirmationRevealed,
                    label: 'Confirm password',
                    validator: (value) => AuthValidators.matches(controller.password.text)(value),
                    onSubmitted: (_) => controller.submit(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Obx(() => NoticeBanner(message: controller.session.error.value, tone: NoticeTone.problem)),
                  const SizedBox(height: AppSpacing.md),
                  Obx(
                    () => FilledButton(
                      key: const Key('udm.register'),
                      onPressed: controller.session.busy.value ? null : controller.submit,
                      child: Text(controller.session.busy.value ? 'Creating account…' : 'Create account'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('udm.toSignIn'),
                      onPressed: controller.signIn,
                      child: const Text('I already have an account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
