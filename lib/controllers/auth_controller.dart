import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:product_lytics/routes/app_routes.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final isLoading = false.obs;
  final user = Rxn<User>();

  @override
  void onInit() {
    super.onInit();
    user.bindStream(_auth.authStateChanges());
  }

  Future<void> login() async {
    try {
      EasyLoading.show(status: 'Đang đăng nhập...');
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      EasyLoading.dismiss();
      Get.offAllNamed(AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      EasyLoading.dismiss();
      Get.snackbar(
        'Lỗi',
        e.message ?? 'Đã xảy ra lỗi trong quá trình đăng nhập',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  Future<void> register() async {
    try {
      if (passwordController.text != confirmPasswordController.text) {
        Get.snackbar(
          'Lỗi',
          'Mật khẩu không khớp',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
        );
        return;
      }

      EasyLoading.show(status: 'Đang đăng ký...');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Store user data in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      EasyLoading.dismiss();
      Get.offAllNamed(AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      EasyLoading.dismiss();
      Get.snackbar(
        'Lỗi',
        e.message ?? 'Đã xảy ra lỗi trong quá trình đăng ký',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  Future<void> logout() async {
    try {
      EasyLoading.show(status: 'Đang đăng xuất...');
      await _auth.signOut();
      EasyLoading.dismiss();
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      EasyLoading.dismiss();
      Get.snackbar(
        'Lỗi',
        'Đã xảy ra lỗi trong quá trình đăng xuất',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }
}
