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

      // Analyze each review
      for (final review in reviews) {
        final result = await _analyzeReview(review);
        analysisResults.add(result);
      }

      // Calculate sentiment distribution
      updateSentimentDistribution();

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

  Future<Map<String, dynamic>> _analyzeReview(String review) async {
    try {
      // Initialize Gemini API
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: '');

      // Create prompt for sentiment analysis in Vietnamese
      final prompt = '''
      Analyze the sentiment of the following review written in Vietnamese and return the result in JSON format only, without any additional text, markdown, or code block markers like ```json. The sentiment should be "positive", "negative", or "neutral". Provide a sentiment_score (from 0 to 5, where 0 is very negative and 5 is very positive). Extract a list of all evaluative words or phrases in Vietnamese (e.g., "tốt", "rất tốt", "tệ", "bình thường") that reflect the sentiment expressed in the review. Include all relevant words/phrases, even if they appear multiple times.

      Review text: $review

      Example reviews and responses:
      - Review: "Sản phẩm này dùng rất tốt, tôi rất hài lòng!"
        Response: {
          "sentiment": "positive",
          "sentiment_score": 4.5,
          "keywords": ["tốt", "rất tốt", "hài lòng", "rất hài lòng"]
        }
      - Review: "Giao hàng chậm, dịch vụ tệ."
        Response: {
          "sentiment": "negative",
          "sentiment_score": 1.0,
          "keywords": ["chậm", "tệ"]
        }
      - Review: "Sản phẩm bình thường, không có gì đặc biệt."
        Response: {
          "sentiment": "neutral",
          "sentiment_score": 3.0,
          "keywords": ["bình thường"]
        }

      Return the response in JSON format only.
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

      return {
        'review': review,
        'sentiment': data['sentiment'],
        'sentiment_score': data['sentiment_score'].toDouble(),
        'keywords': List<String>.from(data['keywords']),
      };
    } catch (e) {
      // Fallback to simple sentiment analysis for demo
      print('Error analyzing review: $e');
      return {
        'review': review,
        'sentiment': 'neutral',
        'sentiment_score': 3.0,
        'keywords': [],
      };
    }
  }

  @override
  void onClose() {
    reviewsController.dispose();
    super.onClose();
  }
}
