import 'package:get/get.dart';

class OnboardingController extends GetxController {
  final RxInt pageIndex = 0.obs;

  void nextPage(int totalPages) {
    if (pageIndex.value < totalPages - 1) {
      pageIndex.value++;
    }
  }

  void goToPage(int index) => pageIndex.value = index;
}
