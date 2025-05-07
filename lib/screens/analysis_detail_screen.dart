import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:product_lytics/controllers/analysis_controller.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalysisDetailScreen extends StatelessWidget {
  const AnalysisDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AnalysisController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết Quả Phân Tích'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
              Get.snackbar(
                'Thông báo',
                'Tính năng chia sẻ đang được phát triển',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: theme.colorScheme.surface,
                colorText: theme.colorScheme.onSurface,
                margin: const EdgeInsets.all(16),
                borderRadius: 8,
              );
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.analysisResults.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics,
                  size: 64,
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Không có kết quả phân tích nào',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        final avgScore =
            controller.analysisResults
                .map((result) => result['sentiment_score'] as double)
                .reduce((a, b) => a + b) /
            controller.analysisResults.length;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.colorScheme.background, theme.colorScheme.surface],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phân Bổ Cảm Xúc
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.pie_chart,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Phân Bổ Cảm Xúc',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: [
                                PieChartSectionData(
                                  color: Colors.green,
                                  value:
                                      controller
                                          .sentimentDistribution
                                          .value['positive'],
                                  title:
                                      '${controller.sentimentDistribution.value['positive']?.toStringAsFixed(1)}%',
                                  titleStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  radius: 80,
                                ),
                                PieChartSectionData(
                                  color: Colors.orange,
                                  value:
                                      controller
                                          .sentimentDistribution
                                          .value['neutral'],
                                  title:
                                      '${controller.sentimentDistribution.value['neutral']?.toStringAsFixed(1)}%',
                                  titleStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  radius: 80,
                                ),
                                PieChartSectionData(
                                  color: Colors.red,
                                  value:
                                      controller
                                          .sentimentDistribution
                                          .value['negative'],
                                  title:
                                      '${controller.sentimentDistribution.value['negative']?.toStringAsFixed(1)}%',
                                  titleStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  radius: 80,
                                ),
                              ],
                              sectionsSpace: 0,
                              centerSpaceRadius: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLegendItem(
                              theme,
                              Colors.green,
                              'Tích Cực',
                              controller.sentimentDistribution.value['positive']
                                      ?.toStringAsFixed(1) ??
                                  '0',
                            ),
                            _buildLegendItem(
                              theme,
                              Colors.orange,
                              'Trung Tính',
                              controller.sentimentDistribution.value['neutral']
                                      ?.toStringAsFixed(1) ??
                                  '0',
                            ),
                            _buildLegendItem(
                              theme,
                              Colors.red,
                              'Tiêu Cực',
                              controller.sentimentDistribution.value['negative']
                                      ?.toStringAsFixed(1) ??
                                  '0',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Tổng Quan
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tổng Quan',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildOverviewItem(
                          theme,
                          'Tổng số bình luận',
                          controller.analysisResults.length.toString(),
                          Icons.comment,
                        ),
                        const SizedBox(height: 12),
                        _buildOverviewItem(
                          theme,
                          'Điểm trung bình',
                          avgScore.toStringAsFixed(1),
                          Icons.star,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.list_alt, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Chi Tiết Phân Tích',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...controller.analysisResults.asMap().entries.map((entry) {
                  final index = entry.key;
                  final result = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primary,
                                child: Text('${index + 1}'),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  result['review'] as String? ??
                                      'Không có nội dung',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.sentiment_satisfied,
                                color: _getSentimentColor(
                                  result['sentiment'] as String? ?? 'neutral',
                                ),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _mapSentimentToVietnamese(
                                  result['sentiment'] as String? ?? 'neutral',
                                ),
                                style: TextStyle(
                                  color: _getSentimentColor(
                                    result['sentiment'] as String? ?? 'neutral',
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.star,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (result['sentiment_score'] as double?)
                                        ?.toStringAsFixed(1) ??
                                    '0.0',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          if ((result['keywords'] as List?)?.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children:
                                  (result['keywords'] as List)
                                      .map(
                                        (keyword) => Chip(
                                          label: Text(
                                            keyword.toString(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          backgroundColor: theme
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.1),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLegendItem(
    ThemeData theme,
    Color color,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          '$value%',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.bodyLarge),
          ],
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  String _mapSentimentToVietnamese(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return 'TÍCH CỰC';
      case 'negative':
        return 'TIÊU CỰC';
      case 'neutral':
      default:
        return 'TRUNG TÍNH';
    }
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
