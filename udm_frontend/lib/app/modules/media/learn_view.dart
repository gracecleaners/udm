import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/media_collection.dart';
import '../../data/models/resume_item.dart';
import 'learn_controller.dart';

/// Teaching library arranged like a visual learning dashboard.
class LearnView extends GetView<LearnController> {
  const LearnView({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    child: Obx(() {
      final shelves = controller.shelves.toList();

      return StateView(
        state: controller.state.value,
        failureMessage: controller.failureMessage.value,
        onRetry: controller.load,
        emptyTitle: 'No recordings published yet',
        emptyMessage: 'When the ministry team publishes a teaching series, it will appear here.',
        child: ColoredBox(
          color: AppColors.background,
          child: RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: controller.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _ContinueWatching()),
                if (shelves.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _BrowseHeading(
                      onSeeAll: () => _showAllSeries(context, shelves),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(17, 0, 17, 26),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: coverColumns(
                          MediaQuery.sizeOf(context).width,
                        ),
                        mainAxisSpacing: 13,
                        crossAxisSpacing: 13,
                        childAspectRatio: 1.25,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final shelf = shelves[index];
                        return _SeriesCard(
                          shelf: shelf,
                          onOpen: () => controller.openShelf(shelf),
                        );
                      }, childCount: shelves.length),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }),
  );
}

class _ContinueWatching extends GetView<LearnController> {
  const _ContinueWatching();

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.resume.isEmpty) return const SizedBox.shrink();
    final items = controller.resume.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'Continue Watching',
          icon: AppIcons.playCircle,
          onSeeAll: () => _showResume(context, controller, items),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: _ResumeCard(
            item: items.first,
            onTap: () => controller.openRecording(items.first),
          ),
        ),
      ],
    );
  });
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.item, required this.onTap});

  final ResumeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(21),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: Container(
        height: 126,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: AppColors.mist.withValues(alpha: .8)),
          boxShadow: AppShadows.card(AppColors.mist),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverArt(
                    url: item.imageUrl,
                    monogram: UdmAvatar.initialsFor(item.title),
                    radius: 12,
                    icon: AppIcons.play,
                  ),
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        AppIcons.play,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontFamily: AppFonts.scripture,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Series: ${item.collectionTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: LinearProgressIndicator(
                            value: item.progress,
                            minHeight: 6,
                            backgroundColor: AppColors.mist,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(item.progress * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 36, color: AppColors.mist),
                      const SizedBox(width: 8),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBlue,
                        ),
                        child: const Icon(
                          AppIcons.play,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BrowseHeading extends StatelessWidget {
  const _BrowseHeading({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => _SectionHeading(
    title: 'Browse Series',
    icon: Icons.grid_view_rounded,
    onSeeAll: onSeeAll,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.icon,
    required this.onSeeAll,
  });

  final String title;
  final IconData icon;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 17, 11),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.deepBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
            ),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.deepBlue,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: const Row(
            children: [
              Text('See All', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(width: 2),
              Icon(AppIcons.next, size: 18, color: AppColors.primaryBlue),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.shelf, required this.onOpen});

  final MediaCollection shelf;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(19),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppColors.mist),
          boxShadow: AppShadows.card(AppColors.mist),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverArt(url: shelf.imageUrl, monogram: shelf.monogram, radius: 0),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xD900183F)],
                  stops: [.28, 1],
                ),
              ),
            ),
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${shelf.itemCount} ${shelf.itemCount == 1 ? 'lesson' : 'lessons'}',
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 11,
              right: 8,
              bottom: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shelf.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: AppFonts.scripture,
                        fontSize: 15,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.chevron,
                      color: AppColors.deepBlue,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showAllSeries(
  BuildContext context,
  List<MediaCollection> shelves,
) async {
  final controller = Get.find<LearnController>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(
              'Browse Series',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          for (final shelf in shelves)
            ListTile(
              leading: CoverArt(
                url: shelf.imageUrl,
                monogram: shelf.monogram,
                width: 60,
                height: 48,
                radius: 8,
              ),
              title: Text(shelf.title),
              subtitle: Text('${shelf.itemCount} lessons'),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.openShelf(shelf);
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> _showResume(
  BuildContext context,
  LearnController controller,
  List<ResumeItem> items,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(
              'Continue Watching',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          for (final item in items)
            ListTile(
              leading: CoverArt(
                url: item.imageUrl,
                monogram: UdmAvatar.initialsFor(item.title),
                width: 64,
                height: 48,
                radius: 8,
                icon: AppIcons.play,
              ),
              title: Text(item.title),
              subtitle: Text(
                '${item.collectionTitle} · ${item.remainingLabel}',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.openRecording(item);
              },
            ),
        ],
      ),
    ),
  );
}
