import 'package:get/get.dart';

class ShellController extends GetxController {
  static const int homeTab = 0;
  static const int bibleTab = 1;
  static const int learnTab = 2;
  static const int communityTab = 3;
  static const int profileTab = 4;

  final RxInt tab = homeTab.obs;

  void select(int index) => tab.value = index;
}
