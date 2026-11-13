import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
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
    final theme = Theme.of(context);
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow('Read through', color: theme.colorScheme.primary, icon: AppIcons.bookOpen),
                          const SizedBox(height: 9),
                          AppText(
                            'Devotions',
                            style: AppTypography.editorialTitle(theme.textTheme.bodyLarge!.color!, size: 32),
                          ),
                          const SizedBox(height: 5),
                          AppText(
                            controller.isOfflineCopy
                                ? 'Saved on this device. Pull to refresh when you are online.'
                                : 'Series the ministry team is publishing now.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (controller.isOfflineCopy) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const OfflineChip(),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xl,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _crossAxisCount(context),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.6,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final series = controller.series[index];
                    return FadeIn(
                      delay: Duration(milliseconds: 60 * (index % _crossAxisCount(context))),
                      child: _SeriesTile(
                        series: series,
                        onOpen: () => controller.openSeries(series),
                      ),
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverArt(
                  url: series.coverImageUrl,
                  monogram: series.monogram,
                  monogramSize: 34,
                ),
                // The count is the promise the tile makes, so it sits on the
                // art where the eye lands rather than under the name.
                PositionedDirectional(
                  bottom: AppSpacing.sm,
                  start: AppSpacing.sm,
                  child: MetaPill(
                    label: '${series.dayCount} ${series.dayCount == 1 ? 'day' : 'days'}',
                    icon: AppIcons.calendar,
                    onDark: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            series.title,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (series.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            AppText(
              series.description,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
