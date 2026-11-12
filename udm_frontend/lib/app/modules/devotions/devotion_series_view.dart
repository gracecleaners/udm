import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/devotion_day.dart';
import 'devotion_series_controller.dart';

/// A series opened: its days in the order they are meant to be read.
class DevotionSeriesView extends GetView<DevotionSeriesController> {
  const DevotionSeriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => AppText(controller.series.value?.title ?? 'Devotions')),
      ),
      body: Obx(() => StateView(
        state: controller.state.value,
        failureMessage: controller.failureMessage.value,
        onRetry: controller.load,
        emptyTitle: 'Nothing published in this series yet',
        emptyMessage:
            'The ministry team has not released a day of this series. Check back soon.',
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
                const OfflineChip(message: 'Offline copy of this series'),
                const SizedBox(height: AppSpacing.md),
              ],
              if (controller.series.value?.description.isNotEmpty ?? false) ...[
                AppText(
                  controller.series.value!.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const Eyebrow('Reading order', icon: Icons.auto_stories_outlined),
              const SizedBox(height: AppSpacing.md),
              ...controller.days.map(
                (day) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _DayRow(day: day, onOpen: () => controller.openDay(day)),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onOpen});

  final DevotionDay day;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _DayBadge(day: day),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  day.isIntroduction ? 'Introduction' : 'Day ${day.day}',
                  style: AppTypography.eyebrow(theme.colorScheme.primary),
                ),
                const SizedBox(height: 4),
                AppText(
                  day.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        day.scriptureReference,
                        style: AppTypography.scriptureReference(
                          theme.textTheme.bodySmall?.color ?? AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    MetaPill(label: '${day.readingMinutes} min'),
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

class _DayBadge extends StatelessWidget {
  const _DayBadge({required this.day});

  final DevotionDay day;

  @override
  Widget build(BuildContext context) {
    if (day.isIntroduction) {
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
        '${day.day}',
        style: theme.textTheme.titleLarge?.copyWith(color: AppColors.white),
      ),
    );
  }
}
