import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:product_lytics/controllers/analysis_controller.dart';
import 'package:product_lytics/routes/app_routes.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AnalysisController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử phân tích'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              controller.getAnalysisHistory();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: controller.getAnalysisHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Đã xảy ra lỗi: ${snapshot.error}',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.red),
              ),
            );
          }

          final analyses = snapshot.data ?? [];

          if (analyses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có lịch sử phân tích',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hãy phân tích đánh giá sản phẩm để xem kết quả tại đây',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.analysis),
                    icon: const Icon(Icons.analytics),
                    label: const Text('Bắt đầu phân tích'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: analyses.length,
            itemBuilder: (context, index) {
              final analysis = analyses[index];
              final timestamp = analysis['timestamp']?.toDate();
              final formattedDate =
                  timestamp != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
                      : 'Không xác định';

              final reviewCount = analysis['reviewCount'] ?? 0;
              final sentimentDistribution =
                  analysis['sentimentDistribution'] as Map<String, dynamic>? ??
                  {};

              // Lấy tỷ lệ cảm xúc
              final positivePercent = sentimentDistribution['positive'] ?? 0.0;
              final neutralPercent = sentimentDistribution['neutral'] ?? 0.0;
              final negativePercent = sentimentDistribution['negative'] ?? 0.0;

              // Xác định cảm xúc chính
              String mainSentiment = 'Trung tính';
              Color sentimentColor = Colors.orange;
              if (positivePercent > neutralPercent &&
                  positivePercent > negativePercent) {
                mainSentiment = 'Tích cực';
                sentimentColor = Colors.green;
              } else if (negativePercent > neutralPercent &&
                  negativePercent > positivePercent) {
                mainSentiment = 'Tiêu cực';
                sentimentColor = Colors.red;
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    // Tải kết quả phân tích này vào controller
                    controller.analysisResults.clear();
                    controller.analysisResults.addAll(
                      List<Map<String, dynamic>>.from(
                        analysis['reviews'] ?? [],
                      ),
                    );
                    controller.sentimentDistribution.value =
                        Map<String, double>.from(sentimentDistribution);
                    controller.updateAspectDistribution();

                    // Chuyển đến màn hình chi tiết
                    Get.toNamed(AppRoutes.analysisDetail);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formattedDate,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: sentimentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sentimentColor,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                mainSentiment,
                                style: TextStyle(
                                  color: sentimentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Số lượng đánh giá: $reviewCount',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Phân bố cảm xúc:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: positivePercent.round(),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    bottomLeft: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: neutralPercent.round(),
                              child: Container(height: 8, color: Colors.orange),
                            ),
                            Expanded(
                              flex: negativePercent.round(),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tích cực: $positivePercent%',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Trung tính: $neutralPercent%',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Tiêu cực: $negativePercent%',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
