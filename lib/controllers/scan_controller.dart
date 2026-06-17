import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/food_item.dart';
import '../routes/app_routes.dart';
import '../services/food_api_service.dart';

enum ScanMode { camera, barcode }

class ScanController extends GetxController {
  ScanController({FoodApiService? api}) : _api = api ?? FoodApiService();

  final FoodApiService _api;
  final ImagePicker _picker = ImagePicker();

  final Rx<ScanMode> mode = ScanMode.camera.obs;
  final RxBool isScanning = false.obs;
  final RxString barcodeInput = ''.obs;
  final RxString scanError = ''.obs;
  final Rxn<FoodItem> scanResult = Rxn<FoodItem>();
  final Rxn<Uint8List> capturedImageBytes = Rxn<Uint8List>();
  final RxBool barcodeScanPaused = false.obs;

  MobileScannerController? barcodeScannerController;

  @override
  void onInit() {
    super.onInit();
    ever(mode, _onModeChanged);
  }

  void _onModeChanged(ScanMode value) {
    if (value == ScanMode.barcode) {
      _ensureBarcodeScanner();
    } else {
      _disposeBarcodeScanner();
    }
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

  void setMode(ScanMode value) => mode.value = value;

  Future<void> captureFromCamera() async {
    scanError.value = '';
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (file == null) return;
      await _handlePickedImage(file);
    } catch (e) {
      scanError.value = 'Could not open camera. Check permissions.';
    }
  }

  Future<void> pickFromGallery() async {
    scanError.value = '';
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (file == null) return;
      await _handlePickedImage(file);
    } catch (e) {
      scanError.value = 'Could not open gallery. Check permissions.';
    }
  }

  Future<void> _handlePickedImage(XFile file) async {
    capturedImageBytes.value = await file.readAsBytes();
    await _analyzePhoto();
  }

  /// Placeholder AI analysis — swap with a vision/ML API when ready.
  Future<void> _analyzePhoto() async {
    isScanning.value = true;
    scanResult.value = null;
    scanError.value = '';

    await Future.delayed(const Duration(seconds: 2));

    scanResult.value = const FoodItem(
      name: 'Grilled Chicken Salad',
      caloriesPer100g: 120,
      protein: 12,
      carbs: 6,
      fat: 5,
      emoji: '🥗',
    );
    isScanning.value = false;
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
    barcodeScanPaused.value = false;
    scanError.value = '';
    barcodeScannerController?.start();
  }

  void openFoodDetails(FoodItem food) {
    Get.toNamed(AppRoutes.foodDetails, arguments: food);
  }

  void clearResult() {
    scanResult.value = null;
    scanError.value = '';
    capturedImageBytes.value = null;
    barcodeScanPaused.value = false;
    barcodeScannerController?.start();
  }

  bool get hasCapturedImage => capturedImageBytes.value != null;

  @override
  void onClose() {
    _disposeBarcodeScanner();
    super.onClose();
  }
}
