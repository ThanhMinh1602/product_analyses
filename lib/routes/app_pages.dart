import 'package:get/get.dart';
import 'package:product_lytics/routes/app_routes.dart';
import 'package:product_lytics/screens/splash_screen.dart';
import 'package:product_lytics/screens/auth/login_screen.dart';
import 'package:product_lytics/screens/auth/register_screen.dart';
import 'package:product_lytics/screens/home_screen.dart';
import 'package:product_lytics/screens/analysis_screen.dart';
import 'package:product_lytics/screens/analysis_detail_screen.dart';

class AppPages {
  static final routes = [
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
    GetPage(name: AppRoutes.register, page: () => RegisterScreen()),
    GetPage(name: AppRoutes.home, page: () => const HomeScreen()),
    GetPage(name: AppRoutes.analysis, page: () => AnalysisScreen()),
    GetPage(name: AppRoutes.analysisDetail, page: () => AnalysisDetailScreen()),
  ];
}
