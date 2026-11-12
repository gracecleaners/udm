import 'package:get/get.dart';

import '../content_version/content_version_controller.dart';

class ShellController extends GetxController {
  static const int homeTab = 0;
  static const int devotionsTab = 1;
  static const int bibleTab = 2;
  static const int learnTab = 3;
  static const int profileTab = 4;

  final RxInt tab = homeTab.obs;

  /// Moving between tabs is the app's cheapest "am I up to date?" moment: the
  /// student is about to look at a screen they have not seen since the last
  /// edit, and one integer request tells every loaded screen whether to refetch.
  void select(int index) {
    tab.value = index;
    Get.find<ContentVersionController>().poll();
  }
}
