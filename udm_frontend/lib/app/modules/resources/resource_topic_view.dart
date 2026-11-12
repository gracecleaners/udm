import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/resource_step.dart';
import 'resource_topic_controller.dart';

/// A guide opened: its steps in the order the ministry wrote them.
class ResourceTopicView extends GetView<ResourceTopicController> {
  const ResourceTopicView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => AppText(controller.topic.value?.title ?? 'Resources')),
      ),
      body: Obx(() => StateView(
        state: controller.state.value,
        failureMessage: controller.failureMessage.value,
        onRetry: controller.load,
        emptyTitle: 'Nothing published in this guide yet',
        emptyMessage:
            'The ministry team has not released a step of this guide. Check back soon.',
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.md,
              AppSpacing.screen,
              AppSpacing.xl,
            ),
            children: [
              if (controller.isOfflineCopy) ...[
                const OfflineChip(message: 'Offline copy of this guide'),
                const SizedBox(height: AppSpacing.md),
              ],
              if (controller.topic.value?.summary.isNotEmpty ?? false) ...[
                AppText(
                  controller.topic.value!.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const Eyebrow('Step order', icon: Icons.format_list_numbered_rounded),
              const SizedBox(height: AppSpacing.md),
              ...controller.steps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _StepRow(step: step, onOpen: () => controller.openStep(step)),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.onOpen});

  final ResourceStep step;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _StepBadge(step: step),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  step.isStartingPoint ? 'Starting point' : 'Step ${step.order}',
                  style: AppTypography.eyebrow(theme.colorScheme.primary),
                ),
                const SizedBox(height: 4),
                AppText(
                  step.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        step.scriptureReference,
                        style: AppTypography.scriptureReference(
                          theme.textTheme.bodySmall?.color ?? AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Only a step the ministry attached a real link to shows
                    // the play mark; the icon is the promise, so it is never decorative.
                    if (step.hasVideo) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.play_circle_outline_rounded,
                          size: 18, color: theme.colorScheme.primary),
                    ],
                    const SizedBox(width: AppSpacing.sm),
                    MetaPill(label: '${step.readingMinutes} min'),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step});

  final ResourceStep step;

  @override
  Widget build(BuildContext context) {
    if (step.isStartingPoint) {
      return const IconBadge(icon: Icons.play_arrow_rounded, size: 46, tone: IconBadgeTone.gold);
    }
    final theme = Theme.of(context);
    return Container(
      width: AppSpacing.iconTile,
      height: AppSpacing.iconTile,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
        boxShadow: AppShadows.glow(AppColors.primaryBlue),
      ),
      child: AppText(
        '${step.order}',
        style: theme.textTheme.titleLarge?.copyWith(color: AppColors.white),
      ),
    );
  }
}
