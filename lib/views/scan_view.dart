import 'dart:typed_data';

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
      appBar: AppBar(title: const Text('Scan Food')),
      body: ResponsivePage(
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              final mode = controller.mode.value;
              return SegmentedButton<ScanMode>(
                segments: const [
                  ButtonSegment(
                    value: ScanMode.camera,
                    label: Text('AI Scan'),
                    icon: Icon(Icons.camera_alt_outlined),
                  ),
                  ButtonSegment(
                    value: ScanMode.barcode,
                    label: Text('Barcode'),
                    icon: Icon(Icons.qr_code_scanner),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => controller.setMode(s.first),
              );
            }),
            SizedBox(height: r.scale(16)),
            Expanded(
              child: Obx(() {
                if (controller.mode.value == ScanMode.camera) {
                  return const _CameraScanPanel();
                }
                return const _BarcodeScanPanel();
              }),
            ),
            Obx(() {
              final error = controller.scanError.value;
              if (error.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
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

class _CameraScanPanel extends GetView<ScanController> {
  const _CameraScanPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final scanning = controller.isScanning.value;
      final imageBytes = controller.capturedImageBytes.value;

      return Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                color: Colors.black87,
                child: _buildPreview(imageBytes, scanning),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: scanning ? null : controller.pickFromGallery,
                  icon: Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: scanning ? null : controller.captureFromCamera,
                  icon: Icon(Icons.camera_alt),
                  label: Text(scanning ? 'Analyzing...' : 'Take Photo'),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildPreview(Uint8List? imageBytes, bool scanning) {
    if (scanning) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Analyzing food...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    if (imageBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black54,
              child: const Text(
                'Photo captured — tap Take Photo to retake',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, size: 64, color: Colors.white54),
        SizedBox(height: 16),
        Text(
          'Take a photo or pick from gallery',
          style: TextStyle(color: Colors.white70),
        ),
      ],
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
                        // Viewfinder overlay
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
