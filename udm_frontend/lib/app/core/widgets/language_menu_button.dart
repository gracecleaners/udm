import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../modules/settings/app_language_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class LanguageMenuButton extends GetView<AppLanguageController> {
  const LanguageMenuButton({super.key, this.onDark = false});

  /// On the brand gradient the icon has to be white to stay visible.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(
      () => PopupMenuButton<String>(
        tooltip: 'Choose language'.tr,
        initialValue: controller.locale.value.languageCode,
        onSelected: controller.select,
        // The menu is a lifted surface, which dark mode keeps in
        // `AppSurfaces.elevated` rather than in `colorScheme`.
        color: theme.extension<AppSurfaces>()?.elevated ?? theme.colorScheme.surface,
        icon: Icon(
          Icons.translate_rounded,
          color: onDark ? AppColors.white : null,
        ),
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: 'en',
            checked: controller.locale.value.languageCode == 'en',
            child: const AppText('English'),
          ),
          CheckedPopupMenuItem(
            value: 'fr',
            checked: controller.locale.value.languageCode == 'fr',
            child: const AppText('Français'),
          ),
        ],
      ),
    );
  }
}
