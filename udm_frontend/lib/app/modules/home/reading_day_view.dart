import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/todays_reading.dart';
import '../shell/shell_controller.dart';
import 'home_controller.dart';

/// One day of the ministry's reading plan, in the four sections it was written
/// in: the passage to read, the verse to hold, what it says, and what to learn.
///
/// Nothing here is looked up again. The day arrives with the dashboard and is
/// cached with it, so a student out of data still reads the same four sections
/// they saw at home.
class ReadingDayView extends GetView<HomeController> {
  const ReadingDayView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText("Today's reading")),
        body: Obx(() {
          final reading = controller.data?.reading;
          if (reading == null) {
            return const CenteredSlot(
              child: MessagePanel(
                icon: AppIcons.bookOpen,
                title: 'No reading plan yet',
                message: 'Once the ministry team publishes a daily plan it opens here.',
              ),
            );
          }
          return _ReadingBody(reading: reading, controller: controller);
        }),
      );
}

class _ReadingBody extends StatelessWidget {
  const _ReadingBody({required this.reading, required this.controller});

  final TodaysReading reading;
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = reading.day;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xxl),
      children: [
        Eyebrow(
          '${reading.planTitle} · Day ${reading.number} of ${reading.total}',
          color: theme.colorScheme.primary,
          icon: AppIcons.bookOpen,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppText(
          day.title.isEmpty ? day.reference : day.title,
          style: AppTypography.editorialTitle(theme.textTheme.bodyLarge!.color!, size: 28),
        ),
        const SizedBox(height: AppSpacing.md),
        UdmProgressBar(fraction: reading.fraction, height: 6, gradient: AppGradients.hero),
        const SizedBox(height: AppSpacing.xs),
        AppText(
          reading.finished
              ? 'All ${reading.total} days read.'
              : '${reading.completed} of ${reading.total} days read.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (day.reference.isNotEmpty)
          _Section(
            eyebrow: 'The passage',
            icon: AppIcons.book,
            child: Panel(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          day.reference,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        AppText(
                          'Read it through before you go on.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  // The Bible tab already holds the translation this student
                  // reads, so the passage opens there rather than in a browser.
                  OutlinedButton.icon(
                    key: const Key('udm.readingDay.openBible'),
                    onPressed: () {
                      Get.back();
                      Get.find<ShellController>().select(ShellController.bibleTab);
                    },
                    icon: const Icon(AppIcons.bookOpen, size: 16),
                    label: const AppText('Open'),
                  ),
                ],
              ),
            ),
          ),
        if (day.verseText.isNotEmpty)
          _Section(
            eyebrow: 'The verse',
            icon: AppIcons.quote,
            child: ScripturePanel(
              compact: true,
              reference: day.verseReference,
              text: day.verseText,
              offline: controller.isOfflineCopy,
            ),
          ),
        if (day.whatItSays.isNotEmpty)
          _Section(
            eyebrow: 'What it says',
            icon: AppIcons.info,
            child: _Prose(text: day.whatItSays),
          ),
        if (day.whatToLearn.isNotEmpty)
          _Section(
            eyebrow: 'What to learn',
            icon: AppIcons.target,
            child: _Prose(text: day.whatToLearn),
          ),
        const SizedBox(height: AppSpacing.lg),
        Obx(() {
          // The footer is the one part of the day that changes while a student
          // stands on it, so it reads the plan off the feed rather than the
          // copy this screen was built with.
          final today = controller.data?.reading?.day ?? day;
          return today.completed
              ? const Panel(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(AppIcons.checkCircle, size: 22, color: AppColors.success),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppText(
                          "Today is on your record. Tomorrow's day opens the next time you come back.",
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('udm.readingDay.markRead'),
                    onPressed: controller.savingReading.value ? null : controller.markReadingFinished,
                    icon: const Icon(AppIcons.check, size: 18),
                    label: const AppText('Mark today as read'),
                  ),
                );
        }),
      ],
    );
  }
}

/// One authored section of the day: the ministry's heading, then its text.
class _Section extends StatelessWidget {
  const _Section({required this.eyebrow, required this.icon, required this.child});

  final String eyebrow;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(eyebrow, color: Theme.of(context).colorScheme.primary, icon: icon),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      );
}

/// A paragraph of ministry prose at the size the student chose for reading.
class _Prose extends StatelessWidget {
  const _Prose({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AppText(
        text,
        style: AppTypography.scriptureBody(theme.textTheme.bodyLarge!.color!, baseSize: 16.5),
      ),
    );
  }
}
