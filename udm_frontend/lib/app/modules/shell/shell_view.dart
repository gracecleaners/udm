import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/widgets/feature_status_view.dart';
import '../home/home_view.dart';
import '../profile/profile_view.dart';
import 'shell_controller.dart';

class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  static const List<Widget> tabs = [
    HomeView(),
    FeatureStatusView(
      title: 'Bible',
      message: 'Read a full licensed or public-domain translation, highlight, and take notes offline.',
      plannedFor: 'Phase 3',
      icon: Icons.menu_book_rounded,
      workingToday: ['Today\'s verse and devotion are on the Home tab'],
    ),
    FeatureStatusView(
      title: 'Learn',
      message: 'Discipleship courses with lessons, quizzes and memory-verse drills.',
      plannedFor: 'Phase 4',
      icon: Icons.school_rounded,
      workingToday: ['Ministry articles open from the Home tab'],
    ),
    FeatureStatusView(
      title: 'Community',
      message: 'Campus fellowships, discipleship groups and moderated discussion.',
      plannedFor: 'Phase 5',
      icon: Icons.groups_rounded,
    ),
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      NavigationDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book),
        label: 'Bible',
      ),
      NavigationDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school),
        label: 'Learn',
      ),
      NavigationDestination(
        icon: Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups),
        label: 'Community',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    return Scaffold(
      body: Obx(() => IndexedStack(index: controller.tab.value, children: tabs)),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          selectedIndex: controller.tab.value,
          onDestinationSelected: controller.select,
          destinations: destinations,
        ),
      ),
    );
  }
}
