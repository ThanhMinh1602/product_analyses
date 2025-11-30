import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:product_lytics/controllers/analysis_controller.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late final AnalysisController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<AnalysisController>();

    // Listen to fetching reviews state and show overlay (only for Tiki fetching)
    ever(controller.isFetchingReviews, (isFetching) {
      if (isFetching) {
        EasyLoading.show(
          status: 'Đang lấy đánh giá từ Tiki...',
          maskType: EasyLoadingMaskType.black,
        );
      } else {
        EasyLoading.dismiss();
      }
    });

    // Don't show EasyLoading for analysis - results screen will handle it
  }

  @override
  Widget build(BuildContext context) {
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
                'Bạn có thể nhập đánh giá thủ công hoặc lấy từ link Tiki. Nhập mỗi đánh giá trên một dòng riêng biệt.',
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.background, theme.colorScheme.surface],
          ),
        ),
        child: _buildUnifiedPage(controller, theme),
      ),
    );
  }

  Widget _buildUnifiedPage(AnalysisController controller, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tiki Link Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_bag,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lấy đánh giá từ Tiki',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dán link sản phẩm Tiki để tự động lấy đánh giá',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () =>
                        controller.productName.value.isNotEmpty
                            ? Card(
                              color: theme.colorScheme.primaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Sản phẩm: ${controller.productName.value}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  theme
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => TextField(
                            controller: controller.tikiUrlController,
                            enabled:
                                !controller.isFetchingReviews.value &&
                                !controller.isLoading.value,
                            decoration: InputDecoration(
                              labelText: 'Link sản phẩm Tiki',
                              hintText: 'https://tiki.vn/...',
                              prefixIcon: const Icon(Icons.link),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor:
                                  controller.isFetchingReviews.value
                                      ? theme.colorScheme.surface.withOpacity(
                                        0.7,
                                      )
                                      : theme.colorScheme.surface,
                            ),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Obx(
                        () => ElevatedButton.icon(
                          onPressed:
                              controller.isFetchingReviews.value ||
                                      controller.isLoading.value
                                  ? null
                                  : () async {
                                    await controller.fetchReviewsFromTiki();
                                  },
                          icon:
                              controller.isFetchingReviews.value
                                  ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  )
                                  : const Icon(Icons.download),
                          label: Text(
                            controller.isFetchingReviews.value
                                ? 'Đang lấy...'
                                : 'Lấy',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Divider with "HOẶC"
          Row(
            children: [
              Expanded(child: Divider(color: theme.colorScheme.outline)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'HOẶC',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: Divider(color: theme.colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 24),
          // Manual Input Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics, color: theme.colorScheme.primary),
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
          // Reviews Input Field
          SizedBox(
            height: 300,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Obx(
                  () => TextField(
                    controller: controller.reviewsController,
                    maxLines: null,
                    expands: true,
                    enabled:
                        !controller.isLoading.value &&
                        !controller.isFetchingReviews.value,
                    decoration: InputDecoration(
                      hintText:
                          'Nhập đánh giá ở đây...\nMỗi đánh giá một dòng\n\nHoặc lấy từ Tiki ở trên',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor:
                          (controller.isLoading.value ||
                                  controller.isFetchingReviews.value)
                              ? theme.colorScheme.surface.withOpacity(0.7)
                              : theme.colorScheme.surface,
                    ),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => ElevatedButton.icon(
                    onPressed:
                        controller.isLoading.value ||
                                controller.isFetchingReviews.value ||
                                controller.reviewsController.text.trim().isEmpty
                            ? null
                            : () async {
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
              ),
              const SizedBox(width: 8),
              Obx(
                () => IconButton(
                  onPressed:
                      controller.isLoading.value ||
                              controller.isFetchingReviews.value
                          ? null
                          : () => controller.clearReviews(),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Xóa tất cả',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
