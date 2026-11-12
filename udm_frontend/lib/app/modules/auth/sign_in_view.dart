import 'package:udm_frontend/app/core/widgets/app_text.dart';
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
      // The backdrop is one continuous surface: a solid app bar would cut it in
      // half at the top of the screen, and a loose Stack would cut it in half at
      // the bottom of the form.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const AppText('Sign in'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.lg),
                      child: UdmLogo(size: 40, tagline: 'Know Christ. Grow in Christ. Make Disciples.'),
                    ),
                    Panel(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Form(
                        key: controller.formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppText('Welcome back', style: theme.textTheme.headlineMedium),
                            const SizedBox(height: AppSpacing.sm),
                            AppText(
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
                            Obx(
                              () => NoticeBanner(message: controller.session.error.value, tone: NoticeTone.problem),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Obx(
                              () => FilledButton.icon(
                                key: const Key('udm.signIn'),
                                onPressed: controller.session.busy.value ? null : controller.submit,
                                icon: Icon(
                                  controller.session.busy.value
                                      ? Icons.hourglass_top_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                                label: AppText(controller.session.busy.value ? 'Signing in…' : 'Sign in'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton(
                              key: const Key('udm.toRegister'),
                              onPressed: controller.register,
                              child: const AppText('Create an account'),
                            ),
                            TextButton(onPressed: controller.explore, child: const AppText('Explore first')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
