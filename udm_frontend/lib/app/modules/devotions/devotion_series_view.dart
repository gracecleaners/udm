import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/devotion_day.dart';
import 'devotion_series_controller.dart';

/// A series opened: its published days in reading order.
class DevotionSeriesView extends GetView<DevotionSeriesController> {
  const DevotionSeriesView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF08090B),
    appBar: AppBar(
      backgroundColor: const Color(0xFF08090B),
      foregroundColor: Colors.white,
      title: Obx(() => AppText(controller.series.value?.title ?? 'Devotions')),
    ),
    body: Obx(
      () => StateView(
        state: controller.state.value,
        failureMessage: controller.failureMessage.value,
        onRetry: controller.load,
        emptyTitle: 'Nothing published in this series yet',
        emptyMessage: 'The ministry team has not released a day of this series. Check back soon.',
        child: Container(
          color: const Color(0xFF08090B),
          child: RefreshIndicator(
            color: const Color(0xFF9AC755),
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                if (controller.isOfflineCopy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: OfflineChip(message: 'Offline copy of this series'),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 18, 22, 12),
                  child: Eyebrow(
                    'READING ORDER',
                    color: Color(0xFF9AC755),
                    icon: AppIcons.bookOpen,
                  ),
                ),
                for (final day in controller.days)
                  _DayRow(day: day, onOpen: () => controller.openDay(day)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onOpen});

  final DevotionDay day;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          child: Row(
            children: [
              CoverArt(
                url: day.imageUrl,
                monogram: day.title.isEmpty
                    ? 'UDM'
                    : day.title[0].toUpperCase(),
                width: 64,
                height: 64,
                radius: 5,
                monogramSize: 22,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      day.isIntroduction
                          ? 'Introduction - ${day.title}'
                          : 'Day ${day.day} - ${day.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (day.scriptureReference.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        day.scriptureReference,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
            ],
          ),
        ),
      ),
      const Divider(height: 1, color: Color(0xFF262626)),
    ],
  );
}
