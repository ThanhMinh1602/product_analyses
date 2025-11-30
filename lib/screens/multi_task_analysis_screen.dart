import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:product_lytics/controllers/analysis_controller.dart';
import 'package:product_lytics/models/analysis_task.dart';
import 'package:product_lytics/routes/app_routes.dart';

class MultiTaskAnalysisScreen extends StatelessWidget {
  const MultiTaskAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AnalysisController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân Tích Nhiều Sản Phẩm'),
        actions: [
          if (controller.tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                Get.dialog(
                  AlertDialog(
                    title: const Text('Xác nhận'),
                    content: const Text('Bạn có chắc muốn xóa tất cả tasks?'),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () {
                          controller.clearAllTasks();
                          Get.back();
                        },
                        child: const Text('Xóa'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Input section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dynamic URL input fields
                Obx(() {
                  return Column(
                    children: [
                      ...controller.urlInputs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final inputController = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index < controller.urlInputs.length - 1
                                    ? 12
                                    : 0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: inputController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Link sản phẩm Tiki ${index + 1}',
                                    hintText: 'https://tiki.vn/...',
                                    prefixIcon: const Icon(Icons.link),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              if (controller.urlInputs.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed:
                                      () =>
                                          controller.removeUrlInputField(index),
                                  tooltip: 'Xóa',
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                // Add button
                OutlinedButton.icon(
                  onPressed: () => controller.addUrlInputField(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm Link'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => controller.clearAllUrlInputs(),
                        icon: const Icon(Icons.clear),
                        label: const Text('Xóa Tất Cả'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Obx(() {
                        final hasUrls = controller.getAllUrls().isNotEmpty;
                        final hasActiveTasks = controller.tasks.any(
                          (task) =>
                              task.status.value != 'completed' &&
                              task.status.value != 'error',
                        );

                        return ElevatedButton.icon(
                          onPressed:
                              hasUrls && !hasActiveTasks
                                  ? () {
                                    controller
                                        .addMultipleAnalysisTasksFromInputs();
                                  }
                                  : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Phân Tích Tất Cả'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tasks list
          Expanded(
            child: Obx(() {
              if (controller.tasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có task nào',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thêm link sản phẩm Tiki để bắt đầu phân tích',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: controller.tasks.length,
                itemBuilder: (context, index) {
                  final task = controller.tasks[index];
                  return _TaskCard(task: task);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final AnalysisTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<AnalysisController>();

    return Obx(() {
      final status = task.status.value;
      final progress = task.progress.value;
      final productName = task.productName.value;
      final errorMessage = task.errorMessage.value;
      final reviewCount = task.analysisResults.length;

      Color statusColor;
      IconData statusIcon;
      String statusText;

      switch (status) {
        case 'pending':
          statusColor = Colors.grey;
          statusIcon = Icons.pending;
          statusText = 'Chờ xử lý';
          break;
        case 'fetching':
          statusColor = Colors.blue;
          statusIcon = Icons.download;
          statusText = 'Đang lấy dữ liệu...';
          break;
        case 'analyzing':
          statusColor = Colors.orange;
          statusIcon = Icons.analytics;
          statusText = 'Đang phân tích...';
          break;
        case 'completed':
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          statusText = 'Hoàn tất';
          break;
        case 'error':
          statusColor = Colors.red;
          statusIcon = Icons.error;
          statusText = 'Lỗi';
          break;
        default:
          statusColor = Colors.grey;
          statusIcon = Icons.help;
          statusText = status;
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap:
              status == 'completed' && task.analysisResults.isNotEmpty
                  ? () {
                    // Navigate to detail screen with this task's data
                    // Temporarily set controller data
                    controller.analysisResults.assignAll(task.analysisResults);
                    controller.sentimentDistribution.value =
                        task.sentimentDistribution.value;
                    controller.aspectDistribution.value =
                        task.aspectDistribution.value;
                    controller.productName.value = task.productName.value;
                    Get.toNamed(AppRoutes.analysisDetail);
                  }
                  : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        productName.isNotEmpty
                            ? productName
                            : 'Đang tải thông tin...',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (status == 'completed' || status == 'error')
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => controller.removeTask(task.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // URL
                Text(
                  task.tikiUrl,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Progress bar
                if (status != 'completed' && status != 'error')
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            statusText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$progress%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                // Completed info
                if (status == 'completed')
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Đã phân tích $reviewCount đánh giá',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Xem chi tiết →',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),

                // Error message
                if (status == 'error' && errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: statusColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
