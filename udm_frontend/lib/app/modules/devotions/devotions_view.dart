import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/devotion_series.dart';
import 'devotions_controller.dart';

/// The Devotions tab: the ministry's reading series as a grid of covers.
class DevotionsView extends GetView<DevotionsController> {
  const DevotionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => StateView(
      state: controller.state.value,
      failureMessage: controller.failureMessage.value,
      onRetry: controller.load,
      emptyTitle: 'No series published yet',
      emptyMessage:
          'When the ministry team publishes a set of devotionals it appears here as a series.',
      child: RefreshIndicator(
        onRefresh: controller.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.md,
                ),
                child: SectionHeader(
                  eyebrow: 'Read through',
                  title: 'Devotions',
                  subtitle: controller.isOfflineCopy
                      ? 'Saved on this device. Pull to refresh when you are online.'
                      : 'Series the ministry team is publishing now.',
                  trailing: controller.isOfflineCopy ? const OfflineChip() : null,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _crossAxisCount(context),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final series = controller.series[index];
                    return _SeriesTile(
                      series: series,
                      onOpen: () => controller.openSeries(series),
                    );
                  },
                  childCount: controller.series.length,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  /// Two covers on a phone, more as the screen widens, so the art keeps its
  /// proportions on a tablet instead of stretching.
  static int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }
}

class _SeriesTile extends StatelessWidget {
  const _SeriesTile({required this.series, required this.onOpen});

  final DevotionSeries series;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              child: series.hasCover
                  ? Image.network(
                      series.coverImageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          _MonogramCover(series: series),
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : const SizedBox.expand(
                              child: SkeletonBox(
                                height: double.infinity,
                                radius: AppSpacing.radiusCard,
                              ),
                            ),
                    )
                  : _MonogramCover(series: series),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            series.title,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          AppText(
            '${series.dayCount} ${series.dayCount == 1 ? 'day' : 'days'}',
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Cover art belongs to the ministry's own host, so a series can exist without
/// a picture. The initials tile is what the grid shows instead of a broken box.
class _MonogramCover extends StatelessWidget {
  const _MonogramCover({required this.series});

  final DevotionSeries series;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: AppGradients.hero),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Mark.backdrop(tint: AppColors.white, alpha: 0.16),
        Center(
          child: AppText(
            series.monogram,
            style: AppTypography.scriptureVerse(AppColors.white, size: 40),
          ),
        ),
      ],
    ),
  );
}
