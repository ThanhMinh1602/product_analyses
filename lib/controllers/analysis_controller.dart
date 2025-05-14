import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:product_lytics/routes/app_routes.dart';

// Controller xử lý phân tích đánh giá sản phẩm sử dụng GetX
class AnalysisController extends GetxController {
  // Khai báo các dịch vụ Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controller để nhập đánh giá và các biến theo dõi trạng thái
  final reviewsController = TextEditingController();
  final isLoading = false.obs; // Trạng thái đang tải
  final analysisResults = <Map<String, dynamic>>[].obs; // Kết quả phân tích

  // Phân phối cảm xúc tổng quát (tích cực, trung tính, tiêu cực)
  final sentimentDistribution = Rx<Map<String, double>>({
    'positive': 0.0,
    'neutral': 0.0,
    'negative': 0.0,
  });

  // Phân phối đặc điểm sản phẩm được đề cập trong đánh giá
  final aspectDistribution = Rx<Map<String, int>>({});

  // Danh sách tất cả các khía cạnh sản phẩm được đề cập
  final allAspects = <String>[].obs;

  // Hàm phân tích đánh giá người dùng
  Future<void> analyzeReviews() async {
    // Kiểm tra đầu vào
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
      isLoading.value = true; // Bắt đầu quá trình tải

      // Tách các đánh giá thành các dòng riêng biệt và loại bỏ dòng trống
      final reviews =
          reviewsController.text
              .split('\n')
              .where((review) => review.trim().isNotEmpty)
              .toList();

      // Xóa kết quả phân tích trước đó
      analysisResults.clear();
      aspectDistribution.value = {};
      allAspects.clear();

      // Phân tích từng đánh giá một
      for (final review in reviews) {
        final result = await _analyzeReviewNLP(review);
        analysisResults.add(result);
      }

      // Tính toán phân phối cảm xúc
      updateSentimentDistribution();

      // Cập nhật phân phối đặc điểm
      updateAspectDistribution();

      // Lưu kết quả phân tích vào Firebase
      await saveAnalysisToFirebase();

      // Chuyển đến màn hình chi tiết kết quả
      reviewsController.clear();
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
      isLoading.value = false; // Kết thúc quá trình tải
    }
  }

  // Cập nhật phân phối cảm xúc tổng thể
  void updateSentimentDistribution() {
    if (analysisResults.isEmpty) {
      sentimentDistribution.value = {
        'positive': 0.0,
        'neutral': 0.0,
        'negative': 0.0,
      };
      return;
    }

    // Tính tỷ lệ phần trăm cho mỗi loại cảm xúc
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

    // Thống kê tần suất xuất hiện của các khía cạnh
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

    // Cập nhật danh sách và phân phối khía cạnh
    allAspects.assignAll(uniqueAspects.toList());
    aspectDistribution.value = aspects;
  }

  // Phân tích đánh giá sử dụng NLP (Xử lý ngôn ngữ tự nhiên)
  Future<Map<String, dynamic>> _analyzeReviewNLP(String review) async {
    try {
      // Khởi tạo API Gemini
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: 'AIzaSyAVbVnn7Xr0UbmSrPwCVmMb-mwvO4r_2xU',
      );

      // Tạo yêu cầu phân tích với định hướng cụ thể
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

      // Gửi yêu cầu đến API Gemini
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      // Ghi log phản hồi từ API
      print('Raw response from Gemini: ${response.text}');

      // Xử lý phản hồi để loại bỏ các ký tự đánh dấu
      String cleanedResponse = response.text!.trim();
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.substring(7).trim();
      }
      if (cleanedResponse.endsWith('```')) {
        cleanedResponse =
            cleanedResponse.substring(0, cleanedResponse.length - 3).trim();
      }

      // Phân tích dữ liệu JSON
      final data = jsonDecode(cleanedResponse);

      // Tính toán phần trăm cảm xúc dựa trên điểm phân cực
      final double polarityScore = data['polarity_score'].toDouble();
      final int sentimentStrength = data['sentiment_strength'];

      // Khởi tạo đối tượng chứa tỷ lệ phần trăm cảm xúc
      Map<String, double> sentimentPercentages = {};

      // Tính toán tỷ lệ cảm xúc dựa trên loại cảm xúc
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
        // Trung lập - phân phối phần trăm còn lại giữa tích cực và tiêu cực
        final remainingPercent = 100 - sentimentStrength.toDouble();
        sentimentPercentages = {
          'positive_percent': remainingPercent / 2,
          'neutral_percent': sentimentStrength.toDouble(),
          'negative_percent': remainingPercent / 2,
        };
      }

      // Trả về kết quả phân tích đã được định dạng
      return {
        'review': data['comment'],
        'main_keywords': List<String>.from(data['main_keywords']),
        'sentiment': data['sentiment'],
        'polarity_score': polarityScore,
        'sentiment_strength': sentimentStrength,
        'sentiment_percentages': sentimentPercentages,
      };
    } catch (e) {
      // Xử lý lỗi và trả về kết quả mặc định khi có lỗi
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

  // Lưu kết quả phân tích vào Firebase
  Future<void> saveAnalysisToFirebase() async {
    try {
      // Kiểm tra xem người dùng đã đăng nhập chưa
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('Không thể lưu: Người dùng chưa đăng nhập');
        return;
      }

      // Tạo đối tượng phân tích để lưu vào Firestore
      final analysisData = {
        'userId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'reviews': analysisResults,
        'sentimentDistribution': sentimentDistribution.value,
        'reviewCount': analysisResults.length,
      };

      // Lưu vào Firestore
      await _firestore.collection('analyses').add(analysisData);

      print('Đã lưu kết quả phân tích vào Firebase');
    } catch (e) {
      print('Lỗi khi lưu kết quả phân tích: $e');
    }
  }

  // Lấy lịch sử phân tích từ Firestore
  Future<List<Map<String, dynamic>>> getAnalysisHistory() async {
    try {
      // Kiểm tra xem người dùng đã đăng nhập chưa
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return [];
      }

      // Truy vấn Firestore để lấy lịch sử phân tích của người dùng hiện tại
      final querySnapshot =
          await _firestore
              .collection('analyses')
              .where('userId', isEqualTo: currentUser.uid)
              .orderBy('timestamp', descending: true)
              .get();

      // Chuyển đổi dữ liệu từ Firestore thành danh sách Map
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Thêm ID tài liệu vào dữ liệu
        return data;
      }).toList();
    } catch (e) {
      print('Lỗi khi lấy lịch sử phân tích: $e');
      return [];
    }
  }

  // Giải phóng tài nguyên khi controller bị hủy
  @override
  void onClose() {
    reviewsController.dispose();
    super.onClose();
  }
}
