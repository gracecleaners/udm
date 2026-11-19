import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/formatted_content.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/devotional.dart';
import '../reader/reading_progress.dart';
import 'devotion_controller.dart';

/// One continuous reading page: a full-screen day title followed by the
/// published scripture reflection, application, and prayer.
class DevotionView extends GetView<DevotionController> {
  const DevotionView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Obx(
      () => StateView(
        state: controller.state.value,
        failureMessage: controller.failureMessage.value,
        onRetry: controller.load,
        emptyTitle: 'Devotion unavailable',
        emptyMessage: 'This devotion is no longer published.',
        child: controller.devotional.value == null
            ? const SizedBox.shrink()
            : _DevotionBody(
                devotional: controller.devotional.value!,
                controller: controller,
              ),
      ),
    ),
  );
}

class _DevotionBody extends StatelessWidget {
  const _DevotionBody({required this.devotional, required this.controller});

  final Devotional devotional;
  final DevotionController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dayTitle = devotional.day == null
        ? devotional.title
        : 'Day ${devotional.day}. ${devotional.title}';
    final date = devotional.publishAt == null
        ? ''
        : DateFormat('MMMM d, yyyy').format(devotional.publishAt!.toLocal());
    final seriesLine = devotional.seriesTitle.isEmpty
        ? 'Daily devotion'
        : 'Part of ${devotional.seriesTitle}';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: AppColors.deepBlue,
          foregroundColor: Colors.white,
          expandedHeight: size.height * .72,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (devotional.imageUrl.isNotEmpty)
                  Image.network(
                    devotional.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const DecoratedBox(
                      decoration: BoxDecoration(gradient: AppGradients.hero),
                    ),
                  )
                else
                  const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.hero)),
                if (devotional.imageUrl.isNotEmpty)
                  const ColoredBox(color: Color(0x55000000)),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 62, 28, 30),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 54,
                          height: 54,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.primaryBlue,
                            size: 30,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dayTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          [seriesLine, if (date.isNotEmpty) date].join('  •  '),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (devotional.scriptureText.isNotEmpty) ...[
                    FormattedContent(
                      devotional.scriptureText,
                      style: const TextStyle(
                        color: Color(0xFF343434),
                        fontSize: 15,
                        height: 1.65,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (devotional.scriptureReference.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            '—${devotional.scriptureReference}',
                            style: const TextStyle(
                              color: Color(0xFF343434),
                        fontSize: 15,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 25),
                      child: Divider(color: Color(0xFFE5E5E5)),
                    ),
                  ] else if (devotional.scriptureReference.isNotEmpty) ...[
                    AppText(
                      devotional.scriptureReference,
                      style: AppTypography.eyebrow(AppColors.primaryBlue),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: FormattedContent(
                      devotional.body,
                      style: const TextStyle(
                        color: Color(0xFF393939),
                        fontSize: 15,
                        height: 1.68,
                      ),
                    ),
                  ),
                  if (devotional.hasQuestions) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFFE5E5E5)),
                    ),
                    const Text(
                      'Reflect',
                      style: TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (
                      var i = 0;
                      i < devotional.reflectionQuestions.length;
                      i++
                    )
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${i + 1}. ${devotional.reflectionQuestions[i]}',
                          style: const TextStyle(
                            color: Color(0xFF393939),
                            fontSize: 16,
                            height: 1.55,
                          ),
                        ),
                      ),
                  ],
                  if (devotional.application.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFFE5E5E5)),
                    ),
                    const Text(
                      'Put it into practice',
                      style: TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FormattedContent(
                      devotional.application,
                      style: const TextStyle(
                        color: Color(0xFF393939),
                        fontSize: 15,
                        height: 1.68,
                      ),
                    ),
                  ],
                  if (devotional.prayer.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(color: Color(0xFFE5E5E5)),
                    ),
                    FormattedContent(
                      devotional.prayer,
                      style: const TextStyle(
                        color: Color(0xFF343434),
                        fontSize: 15,
                        height: 1.7,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '—Prayer',
                        style: TextStyle(
                          color: Color(0xFF343434),
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  ProgressFooter(reader: controller),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
