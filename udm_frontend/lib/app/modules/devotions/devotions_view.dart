import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_art.dart';
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
      emptyTitle: 'Nothing published to read yet',
      emptyMessage:
          'When the ministry team publishes a devotional or a set of them as a series, it appears here.',
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
                                : "Today's reading, then the series to work through.",
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
            const SliverToBoxAdapter(child: _TodaysDevotional()),
            const SliverToBoxAdapter(child: _RecentDevotionals()),
            if (controller.series.isNotEmpty)
              const SliverToBoxAdapter(
                child: RailHeader(
                  eyebrow: 'Work through',
                  title: 'Reading series',
                  subtitle: 'Sets the ministry team is publishing now',
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
                  crossAxisCount: coverColumns(MediaQuery.sizeOf(context).width),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.6,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final series = controller.series[index];
                    return FadeIn(
                      delay: Duration(
                        milliseconds: 60 * (index % coverColumns(MediaQuery.sizeOf(context).width)),
                      ),
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
}

/// The one page the tab opens on: whatever the ministry published most
/// recently, on the ministry's own picture for it.
class _TodaysDevotional extends GetView<DevotionsController> {
  const _TodaysDevotional();

  @override
  Widget build(BuildContext context) => Obx(() {
    final devotion = controller.todays;
    if (devotion == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        0,
      ),
      child: FadeIn(
        delay: const Duration(milliseconds: 40),
        child: FeatureCard(
          eyebrow: "Today's devotional",
          title: devotion.title,
          subtitle: devotion.excerpt.isNotEmpty
              ? devotion.excerpt
              : devotion.scriptureReference,
          artUrl: devotion.imageUrl,
          artAsset: AppArt.devotionalSeason,
          monogram: UdmAvatar.initialsFor(devotion.title),
          onTap: () => controller.openDevotion(devotion),
          pills: [
            MetaPill(
              label: '${devotion.readingMinutes} min',
              icon: AppIcons.clock,
              onDark: true,
            ),
          ],
        ),
      ),
    );
  });
}

/// What sits behind today's page, newest next. The order is the server's, so
/// the staff decide what a student reads after the day's devotion.
class _RecentDevotionals extends GetView<DevotionsController> {
  const _RecentDevotionals();

  @override
  Widget build(BuildContext context) => Obx(() {
    final more = controller.more;
    if (more.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const RailHeader(eyebrow: 'Keep reading', title: 'Recent devotionals'),
        FadeIn(
          delay: const Duration(milliseconds: 80),
          child: DiscoveryRail(
            children: [
              for (final devotion in more)
                RailCard(
                  title: devotion.title,
                  subtitle: devotion.scriptureReference.isEmpty
                      ? devotion.excerpt
                      : devotion.scriptureReference,
                  artUrl: devotion.imageUrl,
                  artAsset: AppArt.devotionalSeason,
                  monogram: UdmAvatar.initialsFor(devotion.title),
                  pill: MetaPill(
                    label: '${devotion.readingMinutes} min',
                    icon: AppIcons.clock,
                  ),
                  onTap: () => controller.openDevotion(devotion),
                ),
            ],
          ),
        ),
      ],
    );
  });
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
