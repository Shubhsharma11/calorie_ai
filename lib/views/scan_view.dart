import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/scan_controller.dart';
import '../core/responsive.dart';
import '../models/food_item.dart';
import '../theme/app_colors.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class ScanView extends GetView<ScanController> {
  const ScanView({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: ResponsivePage(
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: const _BarcodeScanPanel()),
            Obx(() {
              final error = controller.scanError.value;
              if (error.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(top: r.scale(12)),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.error),
                ),
              );
            }),
            Obx(() {
              final result = controller.scanResult.value;
              if (result == null) return const SizedBox.shrink();
              return _ScanResultCard(
                food: result,
                onAdd: () => controller.openFoodDetails(result),
                onDismiss: controller.clearResult,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BarcodeScanPanel extends GetView<ScanController> {
  const _BarcodeScanPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final scanning = controller.isScanning.value;
      final paused = controller.barcodeScanPaused.value;
      final scanner = controller.barcodeScannerController;

      return Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: scanner == null
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: scanner,
                          onDetect: controller.onBarcodeDetected,
                        ),
                        if (paused || scanning)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (scanning)
                                    CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  else
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  const SizedBox(height: 12),
                                  Text(
                                    scanning
                                        ? 'Looking up product...'
                                        : 'Scan paused',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  if (paused && !scanning) ...[
                                    const SizedBox(height: 12),
                                    FilledButton(
                                      onPressed: controller.resumeBarcodeScan,
                                      child: const Text('Scan Again'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 240,
                              height: 140,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Or enter barcode manually',
              hintText: 'e.g. 3017620422003',
              prefixIcon: Icon(Icons.numbers),
            ),
            onChanged: (v) => controller.barcodeInput.value = v,
            onSubmitted: controller.scanBarcode,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: scanning ? 'Looking up...' : 'Look Up Product',
            onPressed: scanning
                ? null
                : () => controller.scanBarcode(controller.barcodeInput.value),
          ),
        ],
      );
    });
  }
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({
    required this.food,
    required this.onAdd,
    required this.onDismiss,
  });

  final FoodItem food;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            FoodEmojiAvatar(emoji: food.emoji, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${food.caloriesPer100g} kcal / 100g',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onDismiss, child: const Text('Clear')),
            FilledButton(onPressed: onAdd, child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}
