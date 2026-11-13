import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/widgets/app_text.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/resource_step.dart';
import '../reader/reading_progress.dart';
import 'resource_step_controller.dart';

class ResourceStepView extends GetView<ResourceStepController> {
  const ResourceStepView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Obx(() => AppText(controller.step.value?.topicTitle ?? 'Guide')),
        ),
        body: Obx(() => StateView(
              state: controller.state.value,
              failureMessage: controller.failureMessage.value,
              onRetry: controller.load,
              emptyTitle: 'Step unavailable',
              emptyMessage: 'This step is no longer published.',
              child: controller.step.value == null
                  ? const SizedBox.shrink()
                  : _StepBody(step: controller.step.value!, controller: controller),
            )),
      );
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.step, required this.controller});

  final ResourceStep step;
  final ResourceStepController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyColor = theme.textTheme.bodyLarge!.color!;
    final paragraphs = step.body
        .split(RegExp(r'\n\s*\n'))
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
      children: [
        if (step.topicTitle.isNotEmpty) ...[
          Eyebrow(
            step.isStartingPoint
                ? '${step.topicTitle} · Starting point'
                : '${step.topicTitle} · Step ${step.order} of ${step.topicStepCount}',
            color: theme.colorScheme.primary,
            icon: AppIcons.steps,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppText(step.title, style: AppTypography.editorialTitle(bodyColor, size: 32)),
        const SizedBox(height: AppSpacing.md),
        const GoldRule(width: 72),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (step.scriptureReference.isNotEmpty)
              MetaPill(icon: AppIcons.book, label: step.scriptureReference),
            MetaPill(icon: AppIcons.clock, label: '${step.readingMinutes} min'),
            if (step.hasVideo) MetaPill(icon: AppIcons.playCircle, label: 'Video'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (step.excerpt.isNotEmpty) ...[
          AppText(
            step.excerpt,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        for (final paragraph in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppText(paragraph.trim(), style: AppTypography.scriptureBody(bodyColor)),
          ),
        if (step.hasVideo) ...[
          const SizedBox(height: AppSpacing.sm),
          Panel(
            child: Row(
              children: [
                const IconBadge(icon: AppIcons.playCircle, size: 38, tone: IconBadgeTone.gold),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('Watch this step', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      AppText(
                        'Opens in your browser, hosted by the ministry.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // A light panel needs a light-surface control; the hero's
                // translucent ghost would be white on white here.
                OutlinedButton.icon(
                  key: const Key('udm.watchStep'),
                  onPressed: controller.openVideo,
                  icon: const Icon(AppIcons.external, size: 16),
                  label: const AppText('Watch'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ProgressFooter(reader: controller),
      ],
    );
  }
}
