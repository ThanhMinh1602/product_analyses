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
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(
                        0.3,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history,
                      size: 48,
                      color: theme.colorScheme.primary.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Chưa có lịch sử phân tích',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Hãy phân tích đánh giá sản phẩm để xem kết quả tại đây',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => Get.toNamed(AppRoutes.analysis),
                    icon: const Icon(Icons.analytics),
                    label: const Text('Bắt đầu phân tích'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                formattedDate,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: sentimentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sentimentColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                mainSentiment,
                                style: TextStyle(
                                  color: sentimentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                if (positivePercent > 0)
                                  Expanded(
                                    flex: (positivePercent * 100).round(),
                                    child: Container(color: Colors.green),
                                  ),
                                if (neutralPercent > 0)
                                  Expanded(
                                    flex: (neutralPercent * 100).round(),
                                    child: Container(color: Colors.orange),
                                  ),
                                if (negativePercent > 0)
                                  Expanded(
                                    flex: (negativePercent * 100).round(),
                                    child: Container(color: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _buildSentimentChip(
                              'Tích cực',
                              positivePercent,
                              Colors.green,
                            ),
                            _buildSentimentChip(
                              'Trung tính',
                              neutralPercent,
                              Colors.orange,
                            ),
                            _buildSentimentChip(
                              'Tiêu cực',
                              negativePercent,
                              Colors.red,
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

  Widget _buildSentimentChip(String label, double percent, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${percent.toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
