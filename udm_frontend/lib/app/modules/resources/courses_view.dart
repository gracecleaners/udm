import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/formatted_content.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/resource_topic.dart';
import 'courses_controller.dart';

/// The Courses screen: every guide the ministry has written, and how far this
/// student is through each one.
///
/// This is not the Learn tab. A course here is a guided read in ordered steps,
/// and the counts on the rows are the server's own, worked out against the
/// steps it has published today.
class CoursesView extends GetView<CoursesController> {
  const CoursesView({super.key, this.newBelieverMode = false});

  final bool newBelieverMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: AppText(newBelieverMode ? 'New Believer' : 'Courses')),
      body: Obx(() => StateView(
        state: controller.state.value,
        failureMessage: controller.failureMessage.value,
        onRetry: controller.load,
        emptyTitle: 'No guides published yet',
        emptyMessage:
            'When the ministry team publishes a guide and its steps, it appears here.',
        emptyIcon: AppIcons.school,
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
              if (newBelieverMode) ...[
                Panel(
                  gradient: AppGradients.tint(
                    theme.extension<AppSurfaces>()!.scripture,
                    theme.colorScheme.surface,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('A first step with Jesus', color: theme.colorScheme.primary, icon: AppIcons.sparkles),
                      const SizedBox(height: AppSpacing.xs),
                      AppText(
                        'Explore the foundations of Christian faith, one short guide at a time. Start with any topic that speaks to you.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (controller.isOfflineCopy) ...[
                const OfflineChip(message: 'Offline copy of the guides'),
                const SizedBox(height: AppSpacing.md),
              ],
              if (controller.started.isNotEmpty) ...[
                Eyebrow(
                  'Pick up where you stopped',
                  color: theme.colorScheme.primary,
                  icon: AppIcons.next,
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._rows(controller.started),
                const SizedBox(height: AppSpacing.lg),
                Eyebrow(
                  'Other guides',
                  color: theme.colorScheme.primary,
                  icon: AppIcons.school,
                ),
              ] else
                Eyebrow(
                  'Guided reading',
                  color: theme.colorScheme.primary,
                  icon: AppIcons.school,
                ),
              const SizedBox(height: AppSpacing.sm),
              if (controller.started.isEmpty)
                AppText(
                  'Short guides for the questions students actually ask, worked through one step at a time.',
                  style: theme.textTheme.bodySmall,
                )
              else
                AppText(
                  'Nothing started in these yet. Each one opens on its first step.',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.md),
              ..._rows(controller.untouched),
            ],
          ),
        ),
      )),
    );
  }

  List<Widget> _rows(List<ResourceTopic> topics) => [
    for (var i = 0; i < topics.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: FadeIn(
          delay: Duration(milliseconds: 55 * i),
          child: _CourseRow(topic: topics[i], onOpen: () => controller.open(topics[i])),
        ),
      ),
  ];
}

/// One guide as a row of the library: its own name, the line the ministry wrote
/// under it, and — only when there is something to say — how far this student
/// has come. An untouched guide gets no empty bar, because an empty bar reads
/// like a fact about the content rather than about the reader.
class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.topic, required this.onOpen});

  final ResourceTopic topic;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final started = topic.stepsCompleted > 0;
    return Panel(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoverArt(
            url: topic.imageUrl,
            monogram: topic.monogram,
            width: AppSpacing.iconTile,
            height: AppSpacing.iconTile,
            radius: AppSpacing.radiusTile,
            monogramSize: 16,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  topic.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (topic.summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  FormattedContent(
                    topic.summary,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                if (started) ...[
                  Row(
                    children: [
                      Expanded(
                        child: AppText(
                          '${topic.stepsCompleted} of ${topic.stepCount} '
                          '${topic.stepCount == 1 ? 'step' : 'steps'} done',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (topic.fractionComplete >= 1)
                        Icon(AppIcons.checkCircle,
                            size: 18, color: AppColors.success),
                    ],
                  ),
                  const SizedBox(height: 7),
                  UdmProgressBar(
                    fraction: topic.fractionComplete,
                    height: 6,
                    gradient: AppGradients.hero,
                  ),
                ] else
                  MetaPill(
                    label: '${topic.stepCount} ${topic.stepCount == 1 ? 'step' : 'steps'}',
                    icon: AppIcons.steps,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(AppIcons.chevron, color: theme.colorScheme.primary, size: 22),
        ],
      ),
    );
  }
}
