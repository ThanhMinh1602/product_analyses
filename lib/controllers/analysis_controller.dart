import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:product_lytics/routes/app_routes.dart';
import 'package:product_lytics/services/tiki_service.dart';
import 'package:product_lytics/services/notification_service.dart';

class AnalysisController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final reviewsController = TextEditingController();
  final tikiUrlController = TextEditingController();
  final isLoading = false.obs;
  final isFetchingReviews = false.obs;
  final analysisResults = <Map<String, dynamic>>[].obs;
  final productName = RxString('');
  final totalReviewsToAnalyze = 0.obs; // Total number of reviews to analyze

  final sentimentDistribution = Rx<Map<String, double>>({
    'positive': 0.0,
    'neutral': 0.0,
    'negative': 0.0,
  });

  final aspectDistribution = Rx<Map<String, int>>({});

  final allAspects = <String>[].obs;

  /// Xóa nội dung trong reviewsController.
  void clearReviews() {
    reviewsController.clear();
    tikiUrlController.clear();
    productName.value = '';
  }

  /// Lấy reviews từ link Tiki và điền vào reviewsController
  Future<void> fetchReviewsFromTiki() async {
    final url = tikiUrlController.text.trim();

    if (url.isEmpty) {
      Get.snackbar(
        'Lỗi',
        'Vui lòng nhập link sản phẩm Tiki',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
      return;
    }

    if (!TikiService.isValidTikiUrl(url)) {
      Get.snackbar(
        'Lỗi',
        'Link không hợp lệ. Vui lòng nhập link sản phẩm Tiki đúng định dạng',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
      return;
    }

    try {
      isFetchingReviews.value = true;

      // Get product name
      final name = await TikiService.getProductName(url);
      if (name != null) {
        productName.value = name;
      }

      // Fetch reviews
      final reviews = await TikiService.fetchReviewsFromTiki(url);

      if (reviews.isEmpty) {
        Get.snackbar(
          'Thông báo',
          'Không tìm thấy đánh giá nào cho sản phẩm này',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange.withOpacity(0.1),
          colorText: Colors.orange,
        );
        return;
      }

      // Fill reviews into controller
      reviewsController.text = reviews.join('\n');

      Get.snackbar(
        'Thành công',
        'Đã lấy ${reviews.length} đánh giá từ Tiki',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.withOpacity(0.1),
        colorText: Colors.green,
      );
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể lấy đánh giá từ Tiki: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    } finally {
      isFetchingReviews.value = false;
    }
  }

  /// Phân tích các đánh giá từ reviewsController, cập nhật kết quả, lưu vào Firebase và chuyển sang màn hình chi tiết.
  Future<void> analyzeReviews() async {
    if (reviewsController.text.trim().isEmpty) {
      Get.snackbar(
        'Lỗi',
        'Vui lòng nhập đánh giá để phân tích',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
      return;
    }

    try {
      isLoading.value = true;

      final reviews =
          reviewsController.text
              .split('\n')
              .where((review) => review.trim().isNotEmpty)
              .toList();

      // Clear previous results
      analysisResults.clear();
      aspectDistribution.value = {};
      allAspects.clear();
      totalReviewsToAnalyze.value = reviews.length;

      // Navigate to results screen immediately
      Get.toNamed(AppRoutes.analysisDetail);

      // Analyze reviews one by one and update results in real-time
      for (int i = 0; i < reviews.length; i++) {
        final review = reviews[i];
        final result = await _analyzeReviewNLP(review);

        // Add result immediately - UI will update automatically via Obx
        analysisResults.add(result);

        // Update distributions after each review
        updateSentimentDistribution();
        updateAspectDistribution();
      }

      // Save to Firebase after all reviews are analyzed
      await saveAnalysisToFirebase();

      // Show notification when analysis is complete
      await NotificationService().showNotification(
        id: 1,
        title: 'Phân tích hoàn tất',
        body: 'Đã phân tích ${reviews.length} đánh giá thành công!',
        payload: 'analysis_complete',
      );

      reviewsController.clear();
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Đã xảy ra lỗi trong quá trình phân tích: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Cập nhật phân phối cảm xúc dựa trên kết quả phân tích hiện tại.
  void updateSentimentDistribution() {
    if (analysisResults.isEmpty) {
      sentimentDistribution.value = {
        'positive': 0.0,
        'neutral': 0.0,
        'negative': 0.0,
      };
      return;
    }

    final total = analysisResults.length;
    final positiveCount =
        analysisResults
            .where((result) => result['sentiment'] == 'positive')
            .length;
    final neutralCount =
        analysisResults
            .where((result) => result['sentiment'] == 'neutral')
            .length;
    final negativeCount =
        analysisResults
            .where((result) => result['sentiment'] == 'negative')
            .length;

    sentimentDistribution.value = {
      'positive': (positiveCount / total) * 100,
      'neutral': (neutralCount / total) * 100,
      'negative': (negativeCount / total) * 100,
    };
  }

  /// Cập nhật phân phối các khía cạnh (aspects) dựa trên kết quả phân tích hiện tại.
  void updateAspectDistribution() {
    if (analysisResults.isEmpty) {
      aspectDistribution.value = {};
      allAspects.clear();
      return;
    }

    final Map<String, int> aspects = {};
    final Set<String> uniqueAspects = {};

    for (final result in analysisResults) {
      if (result.containsKey('aspects')) {
        for (final aspect in result['aspects'] as List<dynamic>) {
          final aspectName = aspect['aspect'] as String;
          uniqueAspects.add(aspectName);
          aspects[aspectName] = (aspects[aspectName] ?? 0) + 1;
        }
      }
    }

    allAspects.assignAll(uniqueAspects.toList());
    aspectDistribution.value = aspects;
  }

  /// Gọi mô hình NLP để phân tích một đánh giá, trả về kết quả dưới dạng Map.
  Future<Map<String, dynamic>> _analyzeReviewNLP(String review) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: 'AIzaSyAJMiI18Oz0Si3E3Yas0mE43Q_V-W3-z7w',
      );

      final prompt = '''
      Phân tích đánh giá sản phẩm bằng tiếng Việt sử dụng NLP, sau đây và trả kết quả dưới dạng JSON. KHÔNG trả về bất kỳ nội dung khác ngoài JSON (không có dấu ``, markdown, hoặc text thừa).

      1. comment: Nội dung bình luận gốc
      2. main_keywords: Danh sách các từ khóa chính được sử dụng để đánh giá (3-5 từ khóa chính)
      3. sentiment: Phân loại cảm xúc tổng thể ("positive", "negative", hoặc "neutral")
      4. polarity_score: Điểm phân cực cảm xúc từ -1.0 đến 1.0 
         - Giá trị > 0 là tích cực
         - Giá trị < 0 là tiêu cực
         - Giá trị ≈ 0 là trung lập
      5. sentiment_strength: Độ mạnh của cảm xúc, quy đổi polarity score thành phần trăm (0-100%)

      Đánh giá: $review

      Ví dụ JSON cho đánh giá tích cực:
      {
        "comment": "Sản phẩm rất tốt, tôi rất hài lòng",
        "main_keywords": ["rất tốt", "hài lòng"],
        "sentiment": "positive",
        "polarity_score": 0.75,
        "sentiment_strength": 75
      }

      Ví dụ JSON cho đánh giá tiêu cực:
      {
        "comment": "Sản phẩm chất lượng kém, rất thất vọng",
        "main_keywords": ["chất lượng kém", "thất vọng"],
        "sentiment": "negative",
        "polarity_score": -0.68,
        "sentiment_strength": 68
      }

      Ví dụ JSON cho đánh giá trung lập:
      {
        "comment": "Sản phẩm bình thường, có ưu điểm và nhược điểm",
        "main_keywords": ["bình thường", "ưu điểm", "nhược điểm"],
        "sentiment": "neutral",
        "polarity_score": 0.05,
        "sentiment_strength": 5
      }

      Chỉ trả về JSON, không kèm theo bất kỳ văn bản giải thích hoặc ghi chú nào.
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      print('Raw response from Gemini: ${response.text}');

      String cleanedResponse = response.text!.trim();
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.substring(7).trim();
      }
      if (cleanedResponse.endsWith('```')) {
        cleanedResponse =
            cleanedResponse.substring(0, cleanedResponse.length - 3).trim();
      }

      final data = jsonDecode(cleanedResponse);

      final double polarityScore = data['polarity_score'].toDouble();
      final int sentimentStrength = data['sentiment_strength'];

      Map<String, double> sentimentPercentages = {};

      if (data['sentiment'] == 'positive') {
        sentimentPercentages = {
          'positive_percent': sentimentStrength.toDouble(),
          'neutral_percent': 100 - sentimentStrength.toDouble(),
          'negative_percent': 0,
        };
      } else if (data['sentiment'] == 'negative') {
        sentimentPercentages = {
          'positive_percent': 0,
          'neutral_percent': 100 - sentimentStrength.toDouble(),
          'negative_percent': sentimentStrength.toDouble(),
        };
      } else {
        final remainingPercent = 100 - sentimentStrength.toDouble();
        sentimentPercentages = {
          'positive_percent': remainingPercent / 2,
          'neutral_percent': sentimentStrength.toDouble(),
          'negative_percent': remainingPercent / 2,
        };
      }

      return {
        'review': data['comment'],
        'main_keywords': List<String>.from(data['main_keywords']),
        'sentiment': data['sentiment'],
        'polarity_score': polarityScore,
        'sentiment_strength': sentimentStrength,
        'sentiment_percentages': sentimentPercentages,
      };
    } catch (e) {
      print('Error analyzing review with NLP: $e');
      return {
        'review': review,
        'main_keywords': [],
        'sentiment': 'neutral',
        'polarity_score': 0.0,
        'sentiment_strength': 0,
        'sentiment_percentages': {
          'positive_percent': 33.3,
          'neutral_percent': 33.4,
          'negative_percent': 33.3,
        },
      };
    }
  }

  /// Lưu kết quả phân tích hiện tại lên Firestore cho người dùng hiện tại.
  Future<void> saveAnalysisToFirebase() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('Không thể lưu: Người dùng chưa đăng nhập');
        return;
      }

      final analysisData = {
        'userId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'reviews': analysisResults,
        'sentimentDistribution': sentimentDistribution.value,
        'reviewCount': analysisResults.length,
      };

      await _firestore.collection('analyses').add(analysisData);

      print('Đã lưu kết quả phân tích vào Firebase');
    } catch (e) {
      print('Lỗi khi lưu kết quả phân tích: $e');
    }
  }

  /// Lấy lịch sử các lần phân tích của người dùng hiện tại từ Firestore.
  Future<List<Map<String, dynamic>>> getAnalysisHistory() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return [];
      }

      final querySnapshot =
          await _firestore
              .collection('analyses')
              .where('userId', isEqualTo: currentUser.uid)
              .orderBy('timestamp', descending: true)
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Lỗi khi lấy lịch sử phân tích: $e');
      return [];
    }
  }

  /// Giải phóng resources khi controller bị hủy.
  @override
  void onClose() {
    reviewsController.dispose();
    tikiUrlController.dispose();
    super.onClose();
  }
}
