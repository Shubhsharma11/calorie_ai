import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final RxBool cameraPermissionDenied = false.obs;
  final RxnString cameraError = RxnString();

  MobileScannerController? barcodeScannerController;
  bool _handlingDetection = false;

  @override
  void onInit() {
    super.onInit();
    _ensureBarcodeScanner();
  }

  void _ensureBarcodeScanner() {
    barcodeScannerController ??= MobileScannerController(
      // Keep camera stable; start/stop is managed by the scan tab.
      autoStart: false,
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.qrCode,
      ],
    );
  }

  void _disposeBarcodeScanner() {
    barcodeScannerController?.dispose();
    barcodeScannerController = null;
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) {
      cameraPermissionDenied.value = false;
      return true;
    }

    status = await Permission.camera.request();
    final granted = status.isGranted;
    cameraPermissionDenied.value = !granted;
    if (!granted && kDebugMode) {
      debugPrint('ScanController: camera permission=$status');
    }
    return granted;
  }

  void onBarcodeDetected(BarcodeCapture capture) {
    if (_handlingDetection || barcodeScanPaused.value || isScanning.value) {
      return;
    }

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    String? code;
    for (final barcode in barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        code = value;
        break;
      }
    }
    if (code == null) return;

    _handlingDetection = true;
    barcodeScanPaused.value = true;
    barcodeScannerController?.stop();
    scanBarcode(code).whenComplete(() {
      _handlingDetection = false;
    });
  }

  Future<void> scanBarcode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    isScanning.value = true;
    scanResult.value = null;
    scanError.value = '';

    try {
      final food = await _api.lookupBarcode(trimmed);
      if (food == null) {
        scanError.value = 'No product found for barcode $trimmed';
        await resumeBarcodeScan();
      } else {
        scanResult.value = food;
        barcodeInput.value = trimmed;
        barcodeScanPaused.value = true;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('ScanController.scanBarcode: $error');
      }
      scanError.value = 'Barcode lookup failed. Check your connection.';
      await resumeBarcodeScan();
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> resumeBarcodeScan() async {
    scanError.value = '';
    cameraError.value = null;
    barcodeScanPaused.value = false;
    _handlingDetection = false;

    final granted = await _ensureCameraPermission();
    if (!granted) return;

    _ensureBarcodeScanner();
    try {
      await barcodeScannerController?.start();
    } catch (error) {
      cameraError.value = 'Could not start camera. Try again.';
      if (kDebugMode) {
        debugPrint('ScanController.resumeBarcodeScan: $error');
      }
    }
  }

  Future<void> pauseBarcodeScan() async {
    barcodeScanPaused.value = true;
    _handlingDetection = false;
    try {
      await barcodeScannerController?.stop();
    } catch (_) {
      // Ignore stop failures when camera was never started.
    }
  }

  void openFoodDetails(FoodItem food) {
    Get.toNamed(AppRoutes.foodDetails, arguments: food);
  }

  Future<void> clearResult() async {
    scanResult.value = null;
    scanError.value = '';
    await resumeBarcodeScan();
  }

  Future<void> openAppSettingsForCamera() => openAppSettings();

  @override
  void onClose() {
    _disposeBarcodeScanner();
    super.onClose();
  }
}
