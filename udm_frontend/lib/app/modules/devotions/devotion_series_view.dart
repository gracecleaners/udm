import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
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
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.deepBlue,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
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
          color: AppColors.background,
          child: RefreshIndicator(
            color: AppColors.primaryBlue,
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
                if (controller.series.value != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
                    child: Text(
                      controller.series.value!.description.isEmpty
                          ? 'Start with the introduction, then continue one day at a time.'
                          : controller.series.value!.description,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        height: 1.5,
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 10, 22, 8),
                  child: Text(
                    'YOUR READING JOURNEY',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final day in controller.days)
                  _DayRow(day: day, onOpen: () => controller.openDay(day)),
              ],
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
              CoverArt(
                url: day.imageUrl,
                monogram: day.title.isEmpty
                    ? 'UDM'
                    : day.title[0].toUpperCase(),
                width: 64,
                height: 64,
                radius: 12,
                monogramSize: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      day.isIntroduction
                          ? (day.title.toLowerCase() == 'introduction' ? 'Introduction' : 'Introduction · ${day.title}')
                          : 'Day ${day.day}. ${day.title}',
                      style: const TextStyle(
                        color: AppColors.deepBlue,
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
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primaryBlue, size: 24),
            ]),
          ),
        ),
      ),
  );
}
