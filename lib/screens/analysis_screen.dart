import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:product_lytics/controllers/analysis_controller.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AnalysisController());

    return Scaffold(
      appBar: AppBar(title: const Text('Review Analysis')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your product reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter each review on a new line',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: controller.reviewsController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Enter reviews here...\nOne review per line',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => ElevatedButton(
                onPressed:
                    controller.isLoading.value
                        ? null
                        : () async {
                          if (controller.reviewsController.text
                              .trim()
                              .isEmpty) {
                            Get.snackbar(
                              'Error',
                              'Please enter at least one review',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                            return;
                          }
                          await controller.analyzeReviews();
                        },
                child:
                    controller.isLoading.value
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Analyze Reviews'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
