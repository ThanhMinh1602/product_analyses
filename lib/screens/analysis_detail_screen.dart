import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:product_lytics/controllers/analysis_controller.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalysisDetailScreen extends StatelessWidget {
  const AnalysisDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AnalysisController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết Quả Phân Tích'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Obx(() {
        if (controller.analysisResults.isEmpty) {
          return const Center(child: Text('Không có kết quả phân tích nào'));
        }

        final avgScore =
            controller.analysisResults
                .map((result) => result['sentiment_score'] as double)
                .reduce((a, b) => a + b) /
            controller.analysisResults.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phân Bổ Cảm Xúc
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân Bổ Cảm Xúc',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              const Text('Tích Cực'),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              const Text('Trung Tính'),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              const Text('Tiêu Cực'),
                            ],
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
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng Quan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tổng số bình luận:'),
                          Text(
                            controller.analysisResults.length.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Điểm trung bình:'),
                          Text(
                            avgScore.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Chi Tiết Phân Tích',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...controller.analysisResults.asMap().entries.map((entry) {
                final index = entry.key;
                final result = entry.value;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text('${index + 1}'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                result['review'] as String? ??
                                    'Không có nội dung',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Cảm xúc: '),
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
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Điểm số: '),
                            Text(
                              (result['sentiment_score'] as double?)
                                      ?.toStringAsFixed(1) ??
                                  '0.0',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if ((result['keywords'] as List?)?.isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 8),
                          const Text('Từ khóa đánh giá:'),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children:
                                (result['keywords'] as List)
                                    .map(
                                      (keyword) => Chip(
                                        label: Text(
                                          keyword.toString(),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.1),
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
        );
      }),
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
