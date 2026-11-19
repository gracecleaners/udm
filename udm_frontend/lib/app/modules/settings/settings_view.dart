import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/udm_widgets.dart';
import '../content_version/content_version_controller.dart';
import 'appearance_controller.dart';
import 'reading_size_sheet.dart';

/// The device's own choices, in one place.
///
/// Everything on this screen belongs to the phone rather than to the account:
/// the light and the size of the reading text. A shared family
/// device can be dark for one student and light for the next, which is exactly
/// why none of it is sent to the server.
///
/// The showcase also drew a Notifications switch and a Data Usage panel here.
/// Neither has an endpoint behind it — the app sends no push and caches nothing
/// a student can measure — so they are left off rather than shown as decoration.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const AppText('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        children: [
          AppText(
            'How the app looks and reads on this device.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Appearance(),
          const SizedBox(height: AppSpacing.lg),
          const _ReadingSize(),
          const SizedBox(height: AppSpacing.lg),
          const _About(),
          const SizedBox(height: AppSpacing.lg),
          const _Help(),
        ],
      ),
    );
  }
}

/// One titled group of settings rows.
class _Group extends StatelessWidget {
  const _Group({
    required this.eyebrow,
    required this.icon,
    required this.children,
  });

  final String eyebrow;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Eyebrow(
        eyebrow,
        color: Theme.of(context).colorScheme.primary,
        icon: icon,
      ),
      const SizedBox(height: AppSpacing.sm),
      Panel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(children: children),
      ),
    ],
  );
}

/// The app stays in its light appearance.
class _Appearance extends StatelessWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context) => _Group(
    eyebrow: 'Appearance',
    icon: AppIcons.sun,
    children: [
      NavRow(
        icon: AppIcons.sun,
        label: 'Light mode',
        trailing: Icon(
          AppIcons.check,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ],
  );
}

/// The reading size the verse cards were proofed at.
class _ReadingSize extends GetView<AppearanceController> {
  const _ReadingSize();

  @override
  Widget build(BuildContext context) => _Group(
    eyebrow: 'Reading',
    icon: AppIcons.textSize,
    children: [
      Obx(
        () => NavRow(
          icon: AppIcons.textSize,
          label: 'Text size',
          subtitle: 'Scripture, devotionals and articles.',
          trailing: MetaPill(
            label: controller.readingSize.label,
            icon: AppIcons.textSize,
          ),
          onTap: () => ReadingSizeSheet.show(context),
          last: true,
        ),
      ),
    ],
  );
}

/// What the app is, and the copy it is currently reading.
class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Group(
      eyebrow: 'About UDM',
      icon: AppIcons.info,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UdmLogo(size: 44, showWordmark: false),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'UDM Discipleship',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      'Scripture, devotion and guided reading for a student '
                      'anywhere on campus — and the staff who publish it.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Obx(() {
          final version = Get.find<ContentVersionController>().known.value;
          return NavRow(
            icon: AppIcons.save,
            label: 'Content on this device',
            subtitle: version == null
                ? 'The app has not heard from the UDM service on this run.'
                : 'Reading the ministry copy published at version $version.',
            trailing: const SizedBox.shrink(),
            last: true,
          );
        }),
      ],
    );
  }
}

/// The answers that are true of this build, rather than a contact form the
/// service has no endpoint for.
class _Help extends StatelessWidget {
  const _Help();

  static const _facts = <String>[
    'Devotions, articles, guides and the Bible read without an account.',
    'A screen you opened keeps its last server copy for when you are offline.',
    'Marking a reading finished writes to your account, so another phone shows the same place.',
    'A prayer you share with a group or the wall goes to a leader before anyone else sees it.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Group(
      eyebrow: 'Help',
      icon: AppIcons.info,
      children: [
        for (final fact in _facts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.checkCircle, size: 18, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppText(fact, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
