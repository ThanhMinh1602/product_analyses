import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:product_lytics/routes/app_routes.dart';

class AnalysisController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final reviewsController = TextEditingController();
  final isLoading = false.obs;
  final analysisResults = <Map<String, dynamic>>[].obs;
  final sentimentDistribution = Rx<Map<String, double>>({
    'positive': 0.0,
    'neutral': 0.0,
    'negative': 0.0,
  });

  // Thêm phân phối đặc điểm sản phẩm
  final aspectDistribution = Rx<Map<String, int>>({});

  // Danh sách tất cả các khía cạnh sản phẩm được đề cập
  final allAspects = <String>[].obs;

  Future<void> analyzeReviews() async {
    if (reviewsController.text.trim().isEmpty) {
      Get.snackbar(
        'Lỗi',
        'Vui lòng nhập đánh giá để phân tích',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
      return;
    }

    try {
      isLoading.value = true;

      // Split reviews into lines and filter empty lines
      final reviews =
          reviewsController.text
              .split('\n')
              .where((review) => review.trim().isNotEmpty)
              .toList();

      // Clear previous results
      analysisResults.clear();
      aspectDistribution.value = {};
      allAspects.clear();

      // Analyze each review
      for (final review in reviews) {
        final result = await _analyzeReviewNLP(review);
        analysisResults.add(result);
      }

      // Calculate sentiment distribution
      updateSentimentDistribution();

      // Update aspect distribution
      updateAspectDistribution();

      // Navigate to results screen
      Get.toNamed(AppRoutes.analysisDetail);
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Đã xảy ra lỗi trong quá trình phân tích: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    } finally {
      isLoading.value = false;
    }
  }

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

  // Cập nhật phân phối các khía cạnh được đề cập trong đánh giá
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

    // Cập nhật RxList và RxMap
    allAspects.assignAll(uniqueAspects.toList());
    aspectDistribution.value = aspects;
  }

  // Phân tích đánh giá theo chuẩn NLP
  Future<Map<String, dynamic>> _analyzeReviewNLP(String review) async {
    try {
      // Initialize Gemini API
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: 'AIzaSyAVbVnn7Xr0UbmSrPwCVmMb-mwvO4r_2xU',
      );

      // Tạo prompt tập trung vào yêu cầu của người dùng với polarity score
      final prompt = '''
      Phân tích đánh giá sản phẩm bằng tiếng Việt sau đây và trả kết quả dưới dạng JSON. KHÔNG trả về bất kỳ nội dung khác ngoài JSON (không có dấu ``, markdown, hoặc text thừa).

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

      // Send request to Gemini API
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      // Debug: Print raw response
      print('Raw response from Gemini: ${response.text}');

      // Clean response to remove ```json or other markers
      String cleanedResponse = response.text!.trim();
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.substring(7).trim();
      }
      if (cleanedResponse.endsWith('```')) {
        cleanedResponse =
            cleanedResponse.substring(0, cleanedResponse.length - 3).trim();
      }

      // Parse JSON response
      final data = jsonDecode(cleanedResponse);

      // Calculate sentiment percentages based on polarity score
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
        // Neutral - distribute remaining percentage between positive and negative
        final remainingPercent = 100 - sentimentStrength.toDouble();
        sentimentPercentages = {
          'positive_percent': remainingPercent / 2,
          'neutral_percent': sentimentStrength.toDouble(),
          'negative_percent': remainingPercent / 2,
        };
      }

      // Chuyển đổi dữ liệu sang định dạng phù hợp
      return {
        'review': data['comment'],
        'main_keywords': List<String>.from(data['main_keywords']),
        'sentiment': data['sentiment'],
        'polarity_score': polarityScore,
        'sentiment_strength': sentimentStrength,
        'sentiment_percentages': sentimentPercentages,
      };
    } catch (e) {
      // Phương án dự phòng khi có lỗi
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

  @override
  void onClose() {
    reviewsController.dispose();
    super.onClose();
  }
}
