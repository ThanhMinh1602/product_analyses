import 'package:get/get.dart';

/// Model để quản lý một task phân tích độc lập
class AnalysisTask {
  final String id;
  final String tikiUrl;
  final RxString status; // 'fetching', 'analyzing', 'completed', 'error'
  final RxString productName;
  final RxList<Map<String, dynamic>> analysisResults;
  final RxInt progress; // 0-100
  final RxString errorMessage;
  final Rx<Map<String, double>> sentimentDistribution;
  final Rx<Map<String, int>> aspectDistribution;

  AnalysisTask({
    required this.id,
    required this.tikiUrl,
    String? initialStatus,
    String? initialProductName,
  })  : status = (initialStatus ?? 'pending').obs,
        productName = (initialProductName ?? '').obs,
        analysisResults = <Map<String, dynamic>>[].obs,
        progress = 0.obs,
        errorMessage = ''.obs,
        sentimentDistribution = Rx<Map<String, double>>({
          'positive': 0.0,
          'neutral': 0.0,
          'negative': 0.0,
        }),
        aspectDistribution = Rx<Map<String, int>>({});

  void updateStatus(String newStatus) {
    status.value = newStatus;
  }

  void updateProgress(int newProgress) {
    progress.value = newProgress;
  }

  void setError(String error) {
    errorMessage.value = error;
    status.value = 'error';
  }

  void addResult(Map<String, dynamic> result) {
    analysisResults.add(result);
  }

  void updateSentimentDistribution(Map<String, double> distribution) {
    sentimentDistribution.value = distribution;
  }

  void updateAspectDistribution(Map<String, int> distribution) {
    aspectDistribution.value = distribution;
  }
}

