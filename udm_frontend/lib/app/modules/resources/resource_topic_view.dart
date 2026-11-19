import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/resource_topic.dart';
import 'resource_topic_controller.dart';

/// Resource cover and action above an expandable overview sheet.
class ResourceTopicView extends GetView<ResourceTopicController> {
  const ResourceTopicView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: Obx(() {
        final topic = controller.topic.value;
        return StateView(
          state: controller.state.value,
          failureMessage: controller.failureMessage.value,
          onRetry: controller.load,
          emptyTitle: 'Resource unavailable',
          emptyMessage: 'This resource is not available right now.',
          child: topic == null
              ? const SizedBox.shrink()
              : _ResourceDetail(
                  topic: topic,
                  offline: controller.isOfflineCopy,
                  onRead: controller.openPdf,
                ),
        );
      }),
    );
  }
}

class _ResourceDetail extends StatelessWidget {
  const _ResourceDetail({
    required this.topic,
    required this.offline,
    required this.onRead,
  });

  final ResourceTopic topic;
  final bool offline;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFEAF2FF)),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundAction(
                      icon: AppIcons.back,
                      label: 'Go back',
                      onTap: () => Get.back(),
                    ),
                    if (offline)
                      const OfflineChip(message: 'Offline copy')
                    else
                      const SizedBox(width: 44),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: screenHeight * .27,
                  child: AspectRatio(
                    aspectRatio: .78,
                    child: CoverArt(
                      url: topic.imageUrl,
                      monogram: topic.monogram,
                      radius: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  topic.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontFamily: AppFonts.scripture,
                    fontSize: 27,
                    height: 1.08,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${topic.stepCount} ${topic.stepCount == 1 ? 'lesson' : 'lessons'}  ·  Resource guide',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 13),
                SizedBox(
                  width: 210,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onRead,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.menu_book_rounded, size: 20),
                    label: const Text(
                      'Read now',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: .25,
          minChildSize: .20,
          maxChildSize: .94,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: AppShadows.float,
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8D4E9),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Overview',
                  style: TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  topic.summary.isEmpty
                      ? 'Explore this resource and grow in your understanding of God’s Word.'
                      : topic.summary,
                  style: const TextStyle(
                    color: Color(0xFF26334A),
                    fontSize: 16,
                    height: 1.65,
                  ),
                ),
                if (topic.stepsCompleted > 0) ...[
                  const SizedBox(height: 18),
                  Text(
                    '${topic.stepsCompleted} of ${topic.stepCount} lessons completed',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  UdmProgressBar(fraction: topic.fractionComplete, height: 7),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    elevation: 3,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: AppColors.deepBlue, semanticLabel: label),
      ),
    ),
  );
}
