import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/article.dart';
import 'articles_controller.dart';

class ArticlesView extends GetView<ArticlesController> {
  const ArticlesView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F1F1),
        surfaceTintColor: Colors.transparent,
        title: const AppText('Articles'),
        actions: [
          Obx(() {
            final categories = controller.categories;
            final selected = controller.category.value;
            return PopupMenuButton<String>(
              tooltip: 'Filter articles',
              initialValue: selected,
              onSelected: (value) => controller.category.value = value,
              itemBuilder: (context) => [
                for (final category in categories)
                  PopupMenuItem<String>(
                    value: category,
                    child: Row(
                      children: [
                        Expanded(child: Text(category)),
                        if (category == selected)
                          Icon(
                            AppIcons.check,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
              ],
              icon: const Icon(AppIcons.filter),
            );
          }),
        ],
      ),
      body: Obx(
        () => StateView(
          state: controller.state.value,
          failureMessage: controller.failureMessage.value,
          onRetry: controller.load,
          emptyTitle: 'No articles published yet',
          emptyMessage: 'New articles from the ministry will appear here.',
          emptyIcon: AppIcons.book,
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, AppSpacing.xl),
              itemCount: controller.visibleArticles.length,
              itemBuilder: (context, index) {
                final article = controller.visibleArticles[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == controller.visibleArticles.length - 1
                        ? 0
                        : 16,
                  ),
                  child: _ArticleTile(
                    article: article,
                    index: index,
                    onTap: () => controller.open(article),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Alternating editorial cards keep the article picture and its preview in
/// one glance, as in the provided reference.
class _ArticleTile extends StatelessWidget {
  const _ArticleTile({
    required this.article,
    required this.index,
    required this.onTap,
  });

  final Article article;
  final int index;
  final VoidCallback onTap;

  bool get _imageOnLeft => index % 4 == 1 || index % 4 == 2;
  bool get _darkTextPanel => index % 4 == 1;

  @override
  Widget build(BuildContext context) {
    final dark = _darkTextPanel;
    final titleColor = dark ? Colors.white : const Color(0xFF555555);
    final secondaryColor = dark
        ? Colors.white.withValues(alpha: .68)
        : const Color(0xFF999999);
    final excerptColor = dark
        ? Colors.white.withValues(alpha: .92)
        : const Color(0xFF777777);

    final image = SizedBox.expand(
      child: CoverArt(
        url: article.imageUrl,
        monogram: UdmAvatar.initialsFor(article.title),
        radius: 0,
        monogramSize: 28,
      ),
    );
    final text = Container(
      color: dark ? const Color(0xFF13090A) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            article.title,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 20,
              height: 1.18,
              fontWeight: FontWeight.w400,
              letterSpacing: -.25,
              color: titleColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          AppText(
            _date(article.publishAt),
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13.5,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: secondaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 15),
          Expanded(
            child: AppText(
              article.preview,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 14.5,
                height: 1.38,
                fontWeight: FontWeight.w400,
                color: excerptColor,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 158,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: _imageOnLeft
                ? [
                    Expanded(flex: 5, child: image),
                    Expanded(flex: 6, child: text),
                  ]
                : [
                    Expanded(flex: 6, child: text),
                    Expanded(flex: 5, child: image),
                  ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime? date) {
    if (date == null) return 'Recently published';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}
