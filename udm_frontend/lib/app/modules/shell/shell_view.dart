import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text.dart';
import '../bible/bible_view.dart';
import '../devotions/devotions_view.dart';
import '../home/home_view.dart';
import '../media/learn_view.dart';
import '../profile/profile_view.dart';
import 'shell_controller.dart';

class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  static const List<Widget> tabs = [
    HomeView(),
    DevotionsView(),
    BibleView(),
    LearnView(),
    ProfileView(),
  ];

  static const List<_Tab> _items = [
    _Tab('Home', Icons.home_outlined, Icons.home_rounded),
    _Tab('Devotions', Icons.auto_stories_outlined, Icons.auto_stories_rounded),
    _Tab('Bible', Icons.menu_book_outlined, Icons.menu_book_rounded),
    _Tab('Learn', Icons.smart_display_outlined, Icons.smart_display_rounded),
    _Tab('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() => IndexedStack(index: controller.tab.value, children: tabs)),
      bottomNavigationBar: Obx(
        () => _TabBar(
          key: const Key('udm.tabBar'),
          items: _items,
          index: controller.tab.value,
          onSelect: controller.select,
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The stock `NavigationBar` caps its indicator at a flat tonal blob. This one
/// carries the brand gradient, moves it with the finger, and keeps the labels
/// legible at 320dp, which is the widest screen a student here does not have.
class _TabBar extends StatelessWidget {
  const _TabBar({super.key, required this.items, required this.index, required this.onSelect});

  final List<_Tab> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.extension<AppSurfaces>()!.hairline)),
            boxShadow: [
              BoxShadow(
                color: theme.extension<AppSurfaces>()!.shadowTint.withValues(alpha: 0.09),
                blurRadius: 22,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _TabItem(
                      tab: items[i],
                      selected: i == index,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 56,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected ? AppGradients.hero : null,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                boxShadow: selected ? AppShadows.glow(surfaces.shadowTint) : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  key: ValueKey(selected),
                  size: 20,
                  color: selected ? AppColors.white : theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AppText(
                tab.label.tr,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.w700,
                  color: selected ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
