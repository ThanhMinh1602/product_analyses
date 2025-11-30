import 'package:get/get.dart';
import 'package:product_lytics/routes/app_routes.dart';
import 'package:product_lytics/screens/splash_screen.dart';
import 'package:product_lytics/screens/auth/login_screen.dart';
import 'package:product_lytics/screens/auth/register_screen.dart';
import 'package:product_lytics/screens/home_screen.dart';
import 'package:product_lytics/screens/analysis_screen.dart';
import 'package:product_lytics/screens/analysis_detail_screen.dart';
import 'package:product_lytics/screens/history_screen.dart';
import 'package:product_lytics/screens/multi_task_analysis_screen.dart';
import 'package:product_lytics/screens/api_key_management_screen.dart';

class AppPages {
  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => RegisterScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.analysis,
      page: () => AnalysisScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.analysisDetail,
      page: () => AnalysisDetailScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.multiTaskAnalysis,
      page: () => const MultiTaskAnalysisScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.history,
      page: () => const HistoryScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: AppRoutes.apiKeyManagement,
      page: () => const ApiKeyManagementScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];
}
