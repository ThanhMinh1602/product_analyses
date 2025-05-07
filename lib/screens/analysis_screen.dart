import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:product_lytics/controllers/analysis_controller.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AnalysisController());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Get.snackbar(
                'Hướng dẫn',
                'Nhập mỗi đánh giá trên một dòng riêng biệt để phân tích chính xác hơn.',
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.background, theme.colorScheme.surface],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                            'Nhập đánh giá sản phẩm',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nhập mỗi đánh giá trên một dòng riêng biệt',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: controller.reviewsController,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText:
                            'Nhập đánh giá ở đây...\nMỗi đánh giá một dòng',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Obx(
                () => ElevatedButton.icon(
                  onPressed:
                      controller.isLoading.value
                          ? null
                          : () async {
                            if (controller.reviewsController.text
                                .trim()
                                .isEmpty) {
                              Get.snackbar(
                                'Lỗi',
                                'Vui lòng nhập ít nhất một đánh giá',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: theme.colorScheme.error,
                                colorText: theme.colorScheme.onError,
                                margin: const EdgeInsets.all(16),
                                borderRadius: 8,
                              );
                              return;
                            }
                            await controller.analyzeReviews();
                          },
                  icon:
                      controller.isLoading.value
                          ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                          : const Icon(Icons.analytics),
                  label: Text(
                    controller.isLoading.value
                        ? 'Đang phân tích...'
                        : 'Phân tích đánh giá',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
