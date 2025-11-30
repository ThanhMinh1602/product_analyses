import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:product_lytics/controllers/analysis_controller.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalysisDetailScreen extends StatefulWidget {
  const AnalysisDetailScreen({super.key});

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  int _lastResultCount = 0;

  @override
  void initState() {
    super.initState();
    final controller = Get.find<AnalysisController>();
    _lastResultCount = controller.analysisResults.length;

    // Listen to analysisResults changes and auto-scroll
    ever(controller.analysisResults, (results) {
      if (results.length > _lastResultCount) {
        // New result added, scroll to bottom after frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients &&
              _scrollController.position.maxScrollExtent > 0) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });
        _lastResultCount = results.length;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
              Get.snackbar(
                'Thông báo',
                'Tính năng chia sẻ đang được phát triển',
                snackPosition: SnackPosition.TOP,
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
        // Show loading state if analyzing
        if (controller.isLoading.value && controller.analysisResults.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.background,
                  theme.colorScheme.surface,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(
                    'Đang phân tích đánh giá...',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vui lòng đợi trong giây lát',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Show empty state if no results and not loading
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

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.colorScheme.background, theme.colorScheme.surface],
            ),
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card(
                //   child: Padding(
                //     padding: const EdgeInsets.all(16.0),
                //     child: Column(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: [
                //         Row(
                //           children: [
                //             Icon(
                //               Icons.pie_chart,
                //               color: theme.colorScheme.primary,
                //             ),
                //             const SizedBox(width: 8),
                //             Text(
                //               'Phân Bổ Cảm Xúc',
                //               style: theme.textTheme.titleMedium?.copyWith(
                //                 fontWeight: FontWeight.bold,
                //               ),
                //             ),
                //           ],
                //         ),
                //         const SizedBox(height: 16),

                //         SizedBox(
                //           height: 200,
                //           child: PieChart(
                //             PieChartData(
                //               sections: [
                //                 PieChartSectionData(
                //                   color: Colors.green,
                //                   value:
                //                       controller
                //                           .sentimentDistribution
                //                           .value['positive'] ??
                //                       0,
                //                   title:
                //                       '${(controller.sentimentDistribution.value['positive'] ?? 0).toStringAsFixed(1)}%',
                //                   titleStyle: const TextStyle(
                //                     fontSize: 16,
                //                     fontWeight: FontWeight.bold,
                //                     color: Colors.white,
                //                   ),
                //                   radius: 80,
                //                 ),

                //                 PieChartSectionData(
                //                   color: Colors.orange,
                //                   value:
                //                       controller
                //                           .sentimentDistribution
                //                           .value['neutral'] ??
                //                       0,
                //                   title:
                //                       '${(controller.sentimentDistribution.value['neutral'] ?? 0).toStringAsFixed(1)}%',
                //                   titleStyle: const TextStyle(
                //                     fontSize: 16,
                //                     fontWeight: FontWeight.bold,
                //                     color: Colors.white,
                //                   ),
                //                   radius: 80,
                //                 ),

                //                 PieChartSectionData(
                //                   color: Colors.red,
                //                   value:
                //                       controller
                //                           .sentimentDistribution
                //                           .value['negative'] ??
                //                       0,
                //                   title:
                //                       '${(controller.sentimentDistribution.value['negative'] ?? 0).toStringAsFixed(1)}%',
                //                   titleStyle: const TextStyle(
                //                     fontSize: 16,
                //                     fontWeight: FontWeight.bold,
                //                     color: Colors.white,
                //                   ),
                //                   radius: 80,
                //                 ),
                //               ],
                //               sectionsSpace: 0,
                //               centerSpaceRadius: 40,
                //             ),
                //           ),
                //         ),
                //         const SizedBox(height: 30),

                //         Row(
                //           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                //           children: [
                //             _buildLegendItem(
                //               theme,
                //               Colors.green,
                //               'Tích Cực',
                //               (controller
                //                           .sentimentDistribution
                //                           .value['positive'] ??
                //                       0)
                //                   .toStringAsFixed(1),
                //             ),
                //             _buildLegendItem(
                //               theme,
                //               Colors.orange,
                //               'Trung Tính',
                //               (controller
                //                           .sentimentDistribution
                //                           .value['neutral'] ??
                //                       0)
                //                   .toStringAsFixed(1),
                //             ),
                //             _buildLegendItem(
                //               theme,
                //               Colors.red,
                //               'Tiêu Cực',
                //               (controller
                //                           .sentimentDistribution
                //                           .value['negative'] ??
                //                       0)
                //                   .toStringAsFixed(1),
                //             ),
                //           ],
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
                // const SizedBox(height: 24),
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
                          'Điểm cảm xúc',
                          _calculateAveragePolarityScore(
                            controller.analysisResults,
                          ),
                          Icons.score,
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
                // Show analyzing indicator if still loading
                if (controller.isLoading.value)
                  Obx(
                    () => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        color: theme.colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  controller.totalReviewsToAnalyze.value > 0
                                      ? 'Đang phân tích ${controller.analysisResults.length}/${controller.totalReviewsToAnalyze.value} đánh giá...'
                                      : 'Đang phân tích đánh giá...',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ...controller.analysisResults.asMap().entries.map((entry) {
                  final index = entry.key;
                  final result = entry.value;

                  // Safely get sentiment_percentages with null check
                  final sentimentPercentagesRaw =
                      result['sentiment_percentages'];
                  final sentimentPercentages =
                      sentimentPercentagesRaw != null
                          ? Map<String, dynamic>.from(
                            sentimentPercentagesRaw as Map,
                          )
                          : <String, double>{
                            'positive_percent': 33.3,
                            'neutral_percent': 33.4,
                            'negative_percent': 33.3,
                          };

                  final positivePercent =
                      sentimentPercentages['positive_percent'] ?? 0.0;
                  final neutralPercent =
                      sentimentPercentages['neutral_percent'] ?? 0.0;
                  final negativePercent =
                      sentimentPercentages['negative_percent'] ?? 0.0;

                  final sentimentStrength =
                      result['sentiment_strength'] as int? ?? 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primary,
                                child: Text('${index + 1}'),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '1. Bình luận:',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      result['review'] as String? ??
                                          'Không có nội dung',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            '2. Từ khóa chính:',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                (result['main_keywords'] as List?)
                                    ?.map(
                                      (keyword) => Chip(
                                        label: Text(
                                          keyword.toString(),
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        backgroundColor: theme
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.1),
                                      ),
                                    )
                                    .toList() ??
                                [],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            '3. Phân tích cảm xúc:',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getSentimentColor(
                                result['sentiment'] as String? ?? 'neutral',
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getSentimentColor(
                                  result['sentiment'] as String? ?? 'neutral',
                                ),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.sentiment_satisfied,
                                          color: _getSentimentColor(
                                            result['sentiment'] as String? ??
                                                'neutral',
                                          ),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _mapSentimentToVietnamese(
                                            result['sentiment'] as String? ??
                                                'neutral',
                                          ),
                                          style: TextStyle(
                                            color: _getSentimentColor(
                                              result['sentiment'] as String? ??
                                                  'neutral',
                                            ),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Icon(
                                      Icons.show_chart,
                                      color: _getSentimentColor(
                                        result['sentiment'] as String? ??
                                            'neutral',
                                      ),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Độ mạnh cảm xúc: ',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    Text(
                                      '$sentimentStrength%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _getSentimentColor(
                                          result['sentiment'] as String? ??
                                              'neutral',
                                        ),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                Text(
                                  'Phân bố cảm xúc:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),

                                if (result['sentiment'] == 'positive')
                                  _buildSentimentBar(
                                    theme,
                                    'Tích cực',
                                    positivePercent.toDouble(),
                                    Colors.green,
                                  )
                                else if (result['sentiment'] == 'negative')
                                  _buildSentimentBar(
                                    theme,
                                    'Tiêu cực',
                                    negativePercent.toDouble(),
                                    Colors.red,
                                  )
                                else
                                  _buildSentimentBar(
                                    theme,
                                    'Trung tính',
                                    neutralPercent.toDouble(),
                                    Colors.orange,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSentimentBar(
    ThemeData theme,
    String label,
    double percentage,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$label: ', style: theme.textTheme.bodyMedium),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            Container(
              height: 8,
              width: percentage * 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
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

  String _calculateAveragePolarityScore(List<Map<String, dynamic>> results) {
    if (results.isEmpty) return "0.00";

    double sum = 0.0;
    for (var result in results) {
      sum += result['polarity_score'] as double? ?? 0.0;
    }

    return "${sum.toStringAsFixed(2)}/${results.length}";
  }
}
