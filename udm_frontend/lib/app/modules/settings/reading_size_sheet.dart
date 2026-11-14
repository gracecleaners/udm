import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/udm_widgets.dart';
import 'appearance_controller.dart';

/// The reading size choice, in one sheet, wherever an "Aa" is pressed.
///
/// Each step is previewed in the real reading style at its real size, so a
/// student sees the chapter they are about to get rather than a promise about
/// a font they will never meet.
class ReadingSizeSheet extends GetView<AppearanceController> {
  const ReadingSizeSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const ReadingSizeSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('Reading size', color: theme.colorScheme.primary),
                    const SizedBox(height: 4),
                    AppText('Scripture and devotions', style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              AppIconButton(icon: AppIcons.close, tooltip: 'Done', size: 38, iconSize: 18, onTap: Get.back),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Obx(
            () => Column(
              children: [
                for (final size in AppearanceController.readingSizes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: PressableScale(
                      onTap: () => controller.selectReadingSize(size),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
                      child: Row(
                        children: [
                          Icon(
                            controller.readingSize == size ? AppIcons.checkCircle : AppIcons.circle,
                            size: 20,
                            color: controller.readingSize == size
                                ? theme.colorScheme.primary
                                : theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(size.label, style: theme.textTheme.titleSmall),
                                const SizedBox(height: 2),
                                AppText(
                                  'For God so loved the world, that he gave his only begotten Son…',
                                  style: AppTypography.scriptureBody(
                                    theme.textTheme.bodyLarge!.color!,
                                    baseSize: 15,
                                    scale: size.scale,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
