import 'package:get/get.dart';
import 'package:product_lytics/controllers/analysis_controller.dart';
import 'package:product_lytics/controllers/auth_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController());
    Get.put(AnalysisController());
  }
}
