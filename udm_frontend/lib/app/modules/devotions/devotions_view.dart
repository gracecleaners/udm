import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/devotion_series.dart';
import 'devotions_controller.dart';

/// Series library: each cover opens the list of days published by the ministry.
class DevotionsView extends GetView<DevotionsController> {
  const DevotionsView({super.key});

  @override
  Widget build(BuildContext context) => Obx(
    () => StateView(
      state: controller.state.value,
      failureMessage: controller.failureMessage.value,
      onRetry: controller.load,
      emptyTitle: 'Nothing published to read yet',
      emptyMessage: 'When the ministry team publishes a devotional series, it will appear here.',
      child: Container(
        color: const Color(0xFF08090B),
        child: RefreshIndicator(
          color: const Color(0xFF9AC755),
          onRefresh: controller.load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Eyebrow(
                              'READ THROUGH',
                              color: Color(0xFF9AC755),
                              icon: AppIcons.bookOpen,
                            ),
                            const SizedBox(height: 8),
                            const AppText(
                              'Devotions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 31,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            AppText(
                              controller.isOfflineCopy
                                  ? 'Saved on this device · pull to refresh online'
                                  : 'Choose a series and follow it one day at a time.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
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
              if (controller.series.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(22, 0, 22, 12),
                    child: AppText(
                      'READING SERIES',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, AppSpacing.xl),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: coverColumns(
                      MediaQuery.sizeOf(context).width,
                    ),
                    mainAxisSpacing: 26,
                    crossAxisSpacing: 24,
                    childAspectRatio: .72,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final series = controller.series[index];
                    return _SeriesTile(
                      series: series,
                      onOpen: () => controller.openSeries(series),
                    );
                  }, childCount: controller.series.length),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SeriesTile extends StatelessWidget {
  const _SeriesTile({required this.series, required this.onOpen});

  final DevotionSeries series;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onOpen,
    borderRadius: BorderRadius.circular(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CoverArt(
            url: series.coverImageUrl,
            monogram: series.monogram,
            monogramSize: 34,
            radius: 8,
          ),
        ),
        const SizedBox(height: 9),
        AppText(
          series.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (series.description.isNotEmpty) ...[
          const SizedBox(height: 3),
          AppText(
            series.description,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    ),
  );
}
