import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import 'auth_controllers.dart';
import 'auth_fields.dart';
import 'validators.dart';

class RegisterView extends GetView<RegisterController> {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // One continuous backdrop; a solid app bar would cut it in half and a
      // loose Stack would stop it at the foot of the form.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const AppText('Create account'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: BrandBackdrop()),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 76, AppSpacing.screen, AppSpacing.xl),
              child: Centered(
                child: Panel(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: controller.formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Eyebrow(
                          'New here',
                          color: theme.colorScheme.primary,
                          icon: AppIcons.sparkles,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppText(
                          'Start your journey',
                          style: AppTypography.editorialTitle(
                            theme.textTheme.bodyLarge!.color!,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppText(
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
                        AppText(
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
                        Obx(
                          () => NoticeBanner(message: controller.session.error.value, tone: NoticeTone.problem),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Obx(
                          () => FilledButton.icon(
                            key: const Key('udm.register'),
                            onPressed: controller.session.busy.value ? null : controller.submit,
                            icon: controller.session.busy.value
                                ? const BusyMark()
                                : const Icon(AppIcons.personAdd, size: 18),
                            label: AppText(
                              controller.session.busy.value ? 'Creating account…' : 'Create account',
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const Key('udm.toSignIn'),
                            onPressed: controller.signIn,
                            child: const AppText('I already have an account'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

