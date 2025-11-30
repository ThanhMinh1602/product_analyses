import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:product_lytics/routes/app_routes.dart';
import 'package:product_lytics/services/tiki_service.dart';
import 'package:product_lytics/services/notification_service.dart';
import 'package:product_lytics/services/api_key_service.dart';
import 'package:product_lytics/models/analysis_task.dart';

/// -------------------------
/// TOP-LEVEL HELPERS
/// -------------------------

/// Hàm clean JSON text do Gemini trả về (xóa ```json, ``` và khoảng trắng thừa)
String _cleanJson(String raw) {
  if (raw.isEmpty) return raw;
  return raw.replaceAll('```json', '').replaceAll('```', '').trim();
}

/// Kết quả default khi parse/AI lỗi
Map<String, dynamic> _defaultAnalysisResult(String review) {
  return {
    'comment': review,
    'review': review,
    'main_keywords': <String>[],
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

/// Hàm parse JSON chạy trong isolate (dùng cho compute)
/// arguments[0] = rawResponse, arguments[1] = review gốc
Map<String, dynamic> parseAnalysisResponse(List<dynamic> arguments) {
  final rawResponse =
      (arguments.isNotEmpty ? (arguments[0] ?? '') : '') as String;
  final review = (arguments.length > 1 ? (arguments[1] ?? '') : '') as String;

  if (rawResponse.trim().isEmpty) {
    return _defaultAnalysisResult(review);
  }

  try {
    final cleaned = _cleanJson(rawResponse);
    final decoded = json.decode(cleaned);

    if (decoded is! Map<String, dynamic>) {
      return _defaultAnalysisResult(review);
    }

    final result = Map<String, dynamic>.from(decoded);

    // Đảm bảo luôn có các field cần thiết
    result['comment'] ??= review;
    result['review'] ??= review;
    result['main_keywords'] ??= <String>[];

    // Validate sentiment
    final sentiment = result['sentiment'];
    if (sentiment != 'positive' &&
        sentiment != 'negative' &&
        sentiment != 'neutral') {
      result['sentiment'] = 'neutral';
    }

    // Validate polarity_score
    final polarity = result['polarity_score'];
    if (polarity is! num) {
      result['polarity_score'] = 0.0;
    }

    // Validate sentiment_strength
    final strength = result['sentiment_strength'];
    if (strength is! num) {
      result['sentiment_strength'] = 0;
    }

    return result;
  } catch (e) {
    // Nếu parse lỗi → trả default
    return _defaultAnalysisResult(review);
  }
}

/// -------------------------
/// CONTROLLER
/// -------------------------

class AnalysisController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiKeyService _apiKeyService = ApiKeyService();

  // Cache API key để tránh query Firestore mỗi lần
  String? _cachedApiKey;
  DateTime? _apiKeyCacheTime;

  // Model Gemini dùng chung (sẽ được khởi tạo với API key từ Firestore)
  GenerativeModel? _geminiModel;
  bool _isModelInitialized = false;

  // Legacy fields
  final reviewsController = TextEditingController();
  final tikiUrlController = TextEditingController();
  final isLoading = false.obs;
  final isFetchingReviews = false.obs;
  final analysisResults = <Map<String, dynamic>>[].obs;
  final productName = RxString('');
  final totalReviewsToAnalyze = 0.obs;

  final sentimentDistribution = Rx<Map<String, double>>({
    'positive': 0.0,
    'neutral': 0.0,
    'negative': 0.0,
  });

  final aspectDistribution = Rx<Map<String, int>>({});
  final allAspects = <String>[].obs;

  // New fields for multi-task processing
  final tasks = <AnalysisTask>[].obs;
  final urlInputController = TextEditingController();
  final urlInputText = ''.obs;

  // Dynamic URL input fields
  final urlInputs = <TextEditingController>[].obs;

  /// Xóa nội dung input review & url
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

      final name = await TikiService.getProductName(url);
      if (name != null) {
        productName.value = name;
      }

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

  /// Phân tích các đánh giá từ reviewsController (single-task)
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

      analysisResults.clear();
      aspectDistribution.value = {};
      allAspects.clear();
      totalReviewsToAnalyze.value = reviews.length;

      // Điều hướng sang màn hình kết quả trước để UI update real-time
      Get.toNamed(AppRoutes.analysisDetail);

      // Batch size nhỏ + dùng chung model để tránh spam API
      const batchSize = 4;

      for (int i = 0; i < reviews.length; i += batchSize) {
        final batch = reviews.skip(i).take(batchSize).toList();

        final batchResults = await Future.wait(
          batch.map((review) => _analyzeReviewGemini(review)),
        );

        for (final result in batchResults) {
          analysisResults.add(result);
        }

        updateSentimentDistribution();
        updateAspectDistribution();

        // Thêm một chút delay để tránh rate-limit nếu nhiều review
        if (i + batchSize < reviews.length) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      await saveAnalysisToFirebase();

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

  /// Cập nhật phân phối sentiment
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

  /// Cập nhật phân phối aspects (nếu bạn dùng aspects trong analysisResults)
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

  /// Gọi Gemini để phân tích một review (dùng model dùng chung)
  Future<Map<String, dynamic>> _analyzeReviewGemini(String review) async {
    // Đảm bảo model đã được khởi tạo
    if (!_isModelInitialized || _geminiModel == null) {
      await _initializeGeminiModel();
    }

    try {
      final prompt = '''
Bạn là chuyên gia phân tích sentiment cho đánh giá sản phẩm. Phân tích đánh giá sau và trả về KẾT QUẢ DƯỚI DẠNG JSON THUẦN (không có markdown, không có dấu backtick, không có text giải thích).

QUAN TRỌNG: 
- Nếu đánh giá có từ ngữ tích cực (tốt, hài lòng, tuyệt vời, đẹp, chất lượng, nhanh, thích, recommend, 5 sao, v.v.) → sentiment phải là "positive" và polarity_score > 0.3
- Nếu đánh giá có từ ngữ tiêu cực (kém, thất vọng, tệ, chậm, lỗi, hỏng, không tốt, không hài lòng, 1-2 sao, v.v.) → sentiment phải là "negative" và polarity_score < -0.3
- CHỈ chọn "neutral" khi đánh giá thực sự trung lập, không có cảm xúc rõ ràng

Đánh giá cần phân tích: "$review"

Trả về JSON với format sau (KHÔNG có markdown, KHÔNG có backtick):
{
  "comment": "nội dung đánh giá gốc",
  "main_keywords": ["từ khóa 1", "từ khóa 2", "từ khóa 3"],
  "sentiment": "positive" hoặc "negative" hoặc "neutral",
  "polarity_score": số từ -1.0 đến 1.0,
  "sentiment_strength": số từ 0 đến 100
}

CHỈ trả về JSON, không có gì khác.
      ''';

      final content = [Content.text(prompt)];

      try {
        final response = await _geminiModel!
            .generateContent(content)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('API call timeout');
              },
            );

        final rawResponse = response.text ?? '';
        debugPrint('Raw response from Gemini: $rawResponse');
        debugPrint('Review being analyzed: $review');

        // Update usage count
        final currentApiKey = await _getApiKey();
        final keyId = await _apiKeyService.findKeyIdByValue(currentApiKey);
        if (keyId != null) {
          _apiKeyService.updateUsageCount(keyId);
        }

        final result = await compute(parseAnalysisResponse, [
          rawResponse,
          review,
        ]);
        debugPrint(
          'Parsed result - sentiment: ${result['sentiment']}, polarity: ${result['polarity_score']}',
        );
        return result;
      } catch (e) {
        // Handle API errors (rate limit, invalid key, etc.)
        final errorMessage = e.toString();
        debugPrint('API Error: $errorMessage');

        // Check if it's a rate limit or quota error
        if (errorMessage.toLowerCase().contains('rate limit') ||
            errorMessage.toLowerCase().contains('quota') ||
            errorMessage.toLowerCase().contains('429')) {
          final currentApiKey = await _getApiKey();
          await _handleApiKeyError(currentApiKey, errorMessage);

          // Retry with new key if available
          await _initializeGeminiModel();
          return _analyzeReviewGemini(review);
        }

        rethrow;
      }
    } catch (e) {
      debugPrint('Error analyzing review with Gemini: $e');
      return _defaultAnalysisResult(review);
    }
  }

  /// Lưu kết quả phân tích hiện tại lên Firestore
  Future<void> saveAnalysisToFirebase() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('Không thể lưu: Người dùng chưa đăng nhập');
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
      debugPrint('Đã lưu kết quả phân tích vào Firebase');
    } catch (e) {
      debugPrint('Lỗi khi lưu kết quả phân tích: $e');
    }
  }

  /// Lịch sử phân tích
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
      debugPrint('Lỗi khi lấy lịch sử phân tích: $e');
      return [];
    }
  }

  /// Thêm single task từ URL Tiki
  Future<void> addAnalysisTask(String tikiUrl) async {
    if (!TikiService.isValidTikiUrl(tikiUrl)) {
      Get.snackbar(
        'Lỗi',
        'Link không hợp lệ. Vui lòng nhập link sản phẩm Tiki đúng định dạng',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
      return;
    }

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = AnalysisTask(
      id: taskId,
      tikiUrl: tikiUrl,
      initialStatus: 'pending',
    );

    tasks.add(task);

    _processTaskInIsolate(task);
  }

  /// Thêm nhiều task từ các input fields
  Future<void> addMultipleAnalysisTasksFromInputs() async {
    final urls = getAllUrls();

    if (urls.isEmpty) {
      Get.snackbar(
        'Lỗi',
        'Vui lòng nhập ít nhất một link',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
      return;
    }

    final validUrls = <String>[];
    final invalidUrls = <String>[];

    for (final url in urls) {
      if (TikiService.isValidTikiUrl(url)) {
        validUrls.add(url);
      } else {
        invalidUrls.add(url);
      }
    }

    if (invalidUrls.isNotEmpty) {
      Get.snackbar(
        'Cảnh báo',
        '${invalidUrls.length} link không hợp lệ đã bị bỏ qua',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.withOpacity(0.1),
        colorText: Colors.orange,
        duration: const Duration(seconds: 3),
      );
    }

    if (validUrls.isEmpty) {
      Get.snackbar(
        'Lỗi',
        'Không có link hợp lệ nào để phân tích',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
      return;
    }

    final List<AnalysisTask> newTasks = [];
    final baseTime = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < validUrls.length; i++) {
      final taskId = (baseTime + i).toString();
      final task = AnalysisTask(
        id: taskId,
        tikiUrl: validUrls[i],
        initialStatus: 'pending',
      );
      newTasks.add(task);
      tasks.add(task);
    }

    clearAllUrlInputs();

    Get.snackbar(
      'Thành công',
      'Đã thêm ${validUrls.length} task. Đang bắt đầu phân tích song song...',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.withOpacity(0.1),
      colorText: Colors.green,
      duration: const Duration(seconds: 2),
    );

    for (int i = 0; i < newTasks.length; i++) {
      final task = newTasks[i];
      if (i > 0) {
        await Future.delayed(Duration(milliseconds: 200 * i));
      }
      _processTaskInIsolate(task);
    }
  }

  /// Xử lý task độc lập
  Future<void> _processTaskInIsolate(AnalysisTask task) async {
    try {
      task.updateStatus('fetching');
      task.updateProgress(10);

      final productName = await TikiService.getProductName(task.tikiUrl);
      if (productName != null) {
        task.productName.value = productName;
      }

      task.updateProgress(20);

      final reviews = await TikiService.fetchReviewsFromTiki(task.tikiUrl);

      if (reviews.isEmpty) {
        task.setError('Không tìm thấy đánh giá nào cho sản phẩm này');
        return;
      }

      task.updateProgress(30);
      task.updateStatus('analyzing');

      final activeTaskCount =
          tasks
              .where(
                (t) =>
                    t.status.value == 'fetching' ||
                    t.status.value == 'analyzing',
              )
              .length;

      final batchSize = activeTaskCount > 3 ? 3 : 4;
      final List<Map<String, dynamic>> results = [];

      for (int i = 0; i < reviews.length; i += batchSize) {
        final batch = reviews.skip(i).take(batchSize).toList();

        final batchResults = await Future.wait(
          batch.map(
            (review) => _analyzeReviewWithComputeWithRetry(review, task.id),
          ),
        );

        for (final result in batchResults) {
          task.addResult(result);
          results.add(result);
        }

        final progress =
            30 + ((i + batch.length) / reviews.length * 60).round();
        task.updateProgress(progress);

        if (i + batchSize < reviews.length && activeTaskCount > 1) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }

      final sentimentDist = _calculateSentimentDistribution(results);
      final aspectDist = _calculateAspectDistribution(results);

      task.updateSentimentDistribution(sentimentDist);
      task.updateAspectDistribution(aspectDist);
      task.updateStatus('completed');
      task.updateProgress(100);

      int notificationId;
      try {
        notificationId = int.parse(task.id) % 1000000;
      } catch (_) {
        notificationId = task.id.hashCode.abs() % 1000000;
      }

      await NotificationService().showNotification(
        id: notificationId,
        title: 'Phân tích hoàn tất',
        body:
            'Đã phân tích ${reviews.length} đánh giá cho ${task.productName.value}',
        payload: 'task_${task.id}',
      );

      await _saveTaskToFirebase(task);
    } catch (e) {
      task.setError('Lỗi khi xử lý: $e');
    }
  }

  /// Phân tích review với retry
  Future<Map<String, dynamic>> _analyzeReviewWithComputeWithRetry(
    String review,
    String taskId,
  ) async {
    const int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        return await _analyzeReviewWithCompute(review, taskId);
      } catch (e) {
        retryCount++;
        debugPrint('Retry $retryCount / $maxRetries for task $taskId: $e');
        if (retryCount >= maxRetries) {
          debugPrint('Failed to analyze review after $maxRetries retries: $e');
          return _defaultAnalysisResult(review);
        }

        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }

    return _defaultAnalysisResult(review);
  }

  /// Phân tích review (multi-task) + parse JSON bằng compute()
  Future<Map<String, dynamic>> _analyzeReviewWithCompute(
    String review,
    String taskId,
  ) async {
    try {
      // Đảm bảo model đã được khởi tạo
      if (_geminiModel == null) {
        await _initializeGeminiModel();
      }

      final prompt = '''
Bạn là chuyên gia phân tích sentiment cho đánh giá sản phẩm. Phân tích đánh giá sau và trả về KẾT QUẢ DƯỚI DẠNG JSON THUẦN (không có markdown, không có dấu backtick, không có text giải thích).

QUAN TRỌNG: 
- Nếu đánh giá có từ ngữ tích cực (tốt, hài lòng, tuyệt vời, đẹp, chất lượng, nhanh, thích, recommend, 5 sao, v.v.) → sentiment phải là "positive" và polarity_score > 0.3
- Nếu đánh giá có từ ngữ tiêu cực (kém, thất vọng, tệ, chậm, lỗi, hỏng, không tốt, không hài lòng, 1-2 sao, v.v.) → sentiment phải là "negative" và polarity_score < -0.3
- CHỈ chọn "neutral" khi đánh giá thực sự trung lập, không có cảm xúc rõ ràng

Đánh giá cần phân tích: "$review"

Trả về JSON với format sau (KHÔNG có markdown, KHÔNG có backtick):
{
  "comment": "nội dung đánh giá gốc",
  "main_keywords": ["từ khóa 1", "từ khóa 2", "từ khóa 3"],
  "sentiment": "positive" hoặc "negative" hoặc "neutral",
  "polarity_score": số từ -1.0 đến 1.0,
  "sentiment_strength": số từ 0 đến 100
}

CHỈ trả về JSON, không có gì khác.
      ''';

      final content = [Content.text(prompt)];

      try {
        final response = await _geminiModel!
            .generateContent(content)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('API call timeout for task $taskId');
              },
            );

        final rawResponse = response.text ?? '';
        debugPrint('Raw response from Gemini (task $taskId): $rawResponse');
        debugPrint('Review being analyzed (task $taskId): $review');

        // Update usage count
        final currentApiKey = await _getApiKey();
        final keyId = await _apiKeyService.findKeyIdByValue(currentApiKey);
        if (keyId != null) {
          _apiKeyService.updateUsageCount(keyId);
        }

        final result = await compute(parseAnalysisResponse, [
          rawResponse,
          review,
        ]);

        debugPrint(
          'Parsed result (task $taskId) - sentiment: ${result['sentiment']}, polarity: ${result['polarity_score']}',
        );

        return result;
      } catch (e) {
        // Handle API errors (rate limit, invalid key, etc.)
        final errorMessage = e.toString();
        debugPrint('API Error for task $taskId: $errorMessage');

        // Check if it's a rate limit or quota error
        if (errorMessage.toLowerCase().contains('rate limit') ||
            errorMessage.toLowerCase().contains('quota') ||
            errorMessage.toLowerCase().contains('429')) {
          final currentApiKey = await _getApiKey();
          await _handleApiKeyError(currentApiKey, errorMessage);

          // Retry with new key if available
          await _initializeGeminiModel();
          return _analyzeReviewWithCompute(review, taskId);
        }

        rethrow;
      }
    } catch (e) {
      debugPrint('Error _analyzeReviewWithCompute (task $taskId): $e');
      return _defaultAnalysisResult(review);
    }
  }

  /// Tính phân phối sentiment
  Map<String, double> _calculateSentimentDistribution(
    List<Map<String, dynamic>> results,
  ) {
    if (results.isEmpty) {
      return {'positive': 0.0, 'neutral': 0.0, 'negative': 0.0};
    }

    final total = results.length;
    final positiveCount =
        results.where((r) => r['sentiment'] == 'positive').length;
    final neutralCount =
        results.where((r) => r['sentiment'] == 'neutral').length;
    final negativeCount =
        results.where((r) => r['sentiment'] == 'negative').length;

    return {
      'positive': (positiveCount / total) * 100,
      'neutral': (neutralCount / total) * 100,
      'negative': (negativeCount / total) * 100,
    };
  }

  /// Tính phân phối keywords (dùng main_keywords làm aspects)
  Map<String, int> _calculateAspectDistribution(
    List<Map<String, dynamic>> results,
  ) {
    final Map<String, int> aspects = {};

    for (final result in results) {
      if (result.containsKey('main_keywords')) {
        for (final keyword in result['main_keywords'] as List<dynamic>) {
          final keywordStr = keyword.toString();
          aspects[keywordStr] = (aspects[keywordStr] ?? 0) + 1;
        }
      }
    }

    return aspects;
  }

  /// Lưu task vào Firebase
  Future<void> _saveTaskToFirebase(AnalysisTask task) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('analyses').add({
        'userId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'tikiUrl': task.tikiUrl,
        'productName': task.productName.value,
        'reviews': task.analysisResults.toList(),
        'sentimentDistribution': task.sentimentDistribution.value,
        'reviewCount': task.analysisResults.length,
        'taskId': task.id,
      });
    } catch (e) {
      debugPrint('Error saving task to Firebase: $e');
    }
  }

  /// Xóa một task
  void removeTask(String taskId) {
    tasks.removeWhere((task) => task.id == taskId);
  }

  /// Xóa tất cả tasks
  void clearAllTasks() {
    tasks.clear();
  }

  /// Lấy API key từ Firestore (với cache)
  Future<String> _getApiKey() async {
    // Cache trong 5 phút
    if (_cachedApiKey != null &&
        _apiKeyCacheTime != null &&
        DateTime.now().difference(_apiKeyCacheTime!).inMinutes < 5) {
      return _cachedApiKey!;
    }

    try {
      final apiKey = await _apiKeyService.getActiveApiKey();
      _cachedApiKey = apiKey;
      _apiKeyCacheTime = DateTime.now();
      return apiKey;
    } catch (e) {
      debugPrint('Error getting API key, using default: $e');
      return 'AIzaSyAJMiI18Oz0Si3E3Yas0mE43Q_V-W3-z7w';
    }
  }

  /// Xử lý lỗi API key (rate limit, invalid, etc.)
  Future<void> _handleApiKeyError(String apiKey, String error) async {
    try {
      final keyId = await _apiKeyService.findKeyIdByValue(apiKey);
      if (keyId != null) {
        final isRateLimit =
            error.toLowerCase().contains('rate limit') ||
            error.toLowerCase().contains('quota') ||
            error.toLowerCase().contains('429');

        await _apiKeyService.markApiKeyAsInvalid(
          keyId,
          rateLimitExceeded: isRateLimit,
        );

        // Clear cache để lấy key mới
        _cachedApiKey = null;
        _apiKeyCacheTime = null;
      }
    } catch (e) {
      debugPrint('Error handling API key error: $e');
    }
  }

  /// Khởi tạo Gemini model với API key từ Firestore
  Future<void> _initializeGeminiModel() async {
    try {
      final apiKey = await _getApiKey();
      _geminiModel = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: apiKey,
      );
      _isModelInitialized = true;
    } catch (e) {
      debugPrint('Error initializing Gemini model: $e');
      // Fallback to default key
      _geminiModel = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: 'AIzaSyAJMiI18Oz0Si3E3Yas0mE43Q_V-W3-z7w',
      );
      _isModelInitialized = true;
    }
  }

  /// onInit
  @override
  void onInit() {
    super.onInit();

    // Initialize Gemini model with API key from Firestore
    _initializeGeminiModel();

    urlInputController.addListener(() {
      urlInputText.value = urlInputController.text;
    });

    addUrlInputField();
  }

  /// Thêm một input field cho URL
  void addUrlInputField() {
    final controller = TextEditingController();
    urlInputs.add(controller);
  }

  /// Xóa một input field
  void removeUrlInputField(int index) {
    if (urlInputs.length > 1) {
      urlInputs[index].dispose();
      urlInputs.removeAt(index);
    }
  }

  /// Lấy tất cả URLs từ các input fields
  List<String> getAllUrls() {
    return urlInputs
        .map((controller) => controller.text.trim())
        .where((url) => url.isNotEmpty)
        .toList();
  }

  /// Xóa tất cả input fields
  void clearAllUrlInputs() {
    for (final controller in urlInputs) {
      controller.dispose();
    }
    urlInputs.clear();
    addUrlInputField();
  }

  /// onClose: giải phóng resources
  @override
  void onClose() {
    reviewsController.dispose();
    tikiUrlController.dispose();
    urlInputController.dispose();

    for (final controller in urlInputs) {
      controller.dispose();
    }
    urlInputs.clear();

    super.onClose();
  }
}
