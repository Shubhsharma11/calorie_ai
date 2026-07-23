import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/food_item.dart';
import '../routes/app_routes.dart';
import '../services/food_api_service.dart';

class ScanController extends GetxController {
  ScanController({FoodApiService? api}) : _api = api ?? FoodApiService();

  final FoodApiService _api;

  final RxBool isScanning = false.obs;
  final RxString barcodeInput = ''.obs;
  final RxString scanError = ''.obs;
  final Rxn<FoodItem> scanResult = Rxn<FoodItem>();
  final RxBool barcodeScanPaused = false.obs;

  MobileScannerController? barcodeScannerController;

  @override
  void onInit() {
    super.onInit();
    _ensureBarcodeScanner();
  }

  void _ensureBarcodeScanner() {
    barcodeScannerController ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.all],
    );
  }

  void _disposeBarcodeScanner() {
    barcodeScannerController?.dispose();
    barcodeScannerController = null;
  }

  void onBarcodeDetected(BarcodeCapture capture) {
    if (barcodeScanPaused.value || isScanning.value) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    barcodeScanPaused.value = true;
    scanBarcode(code);
  }

  Future<void> scanBarcode(String code) async {
    if (code.trim().isEmpty) return;

    isScanning.value = true;
    scanResult.value = null;
    scanError.value = '';

    try {
      final food = await _api.lookupBarcode(code.trim());
      if (food == null) {
        scanError.value = 'No product found for barcode $code';
        barcodeScanPaused.value = false;
      } else {
        scanResult.value = food;
        barcodeInput.value = code.trim();
      }
    } catch (_) {
      scanError.value = 'Barcode lookup failed. Check your connection.';
      barcodeScanPaused.value = false;
    } finally {
      isScanning.value = false;
    }
  }

  void resumeBarcodeScan() {
    if (barcodeScanPaused.value) {
      barcodeScanPaused.value = false;
    }
    if (scanError.value.isNotEmpty) {
      scanError.value = '';
    }
    barcodeScannerController?.start();
  }

  void pauseBarcodeScan() {
    if (!barcodeScanPaused.value) {
      barcodeScanPaused.value = true;
    }
    barcodeScannerController?.stop();
  }

  void openFoodDetails(FoodItem food) {
    Get.toNamed(AppRoutes.foodDetails, arguments: food);
  }

  void clearResult() {
    scanResult.value = null;
    scanError.value = '';
    barcodeScanPaused.value = false;
    barcodeScannerController?.start();
  }

  @override
  void onClose() {
    _disposeBarcodeScanner();
    super.onClose();
  }
}
