import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/formatted_content.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import 'new_believer_controller.dart';

class NewBelieverView extends GetView<NewBelieverController> {
  const NewBelieverView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('New Believer')),
    body: Obx(
      () => StateView(
        state: controller.state.value,
        failureMessage: controller.failureMessage.value,
        onRetry: controller.load,
        emptyTitle: 'No New Believer steps yet',
        emptyMessage: 'The ministry team will add your first steps here.',
        emptyIcon: AppIcons.sparkles,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: controller.steps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final step = controller.steps[index];
              return Panel(
                onTap: () => controller.open(step),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE7F0FF),
                      child: Icon(Icons.menu_book_rounded, color: AppColors.primaryBlue),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(step.title, style: Theme.of(context).textTheme.titleMedium),
                          if (step.excerpt.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            FormattedContent(step.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                          if (step.scriptureReference.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            AppText(step.scriptureReference, style: const TextStyle(color: AppColors.primaryBlue)),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.primaryBlue),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
