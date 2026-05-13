import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/detection_result.dart';

class YOLODetectionService {
  static final YOLODetectionService _instance = YOLODetectionService._internal();
  
  Interpreter? _interpreter;
  bool _isInitialized = false;

  factory YOLODetectionService() {
    return _instance;
  }

  YOLODetectionService._internal();

  // Initialize the YOLO model (call this at app startup)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the TFLite model - place your YOLO model in assets/models/
      _interpreter = await Interpreter.fromAsset('models/yolov8_fridge_detection.tflite');
      _isInitialized = true;
      print('✅ YOLO model loaded successfully');
    } catch (e) {
      print('❌ Error loading YOLO model: $e');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;

  // Run detection on an image
  Future<DetectionResult> detectFromFile(File imageFile) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('YOLO model not initialized. Call initialize() first.');
    }

    try {
      // Read image file
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      return _runInference(image);
    } catch (e) {
      print('❌ Detection error: $e');
      rethrow;
    }
  }

  // Run detection on raw image bytes
  Future<DetectionResult> detectFromBytes(Uint8List imageBytes) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('YOLO model not initialized. Call initialize() first.');
    }

    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      return _runInference(image);
    } catch (e) {
      print('❌ Detection error: $e');
      rethrow;
    }
  }

  Future<DetectionResult> _runInference(img.Image image) async {
    try {
      // Resize image to model input size (typically 640x640 for YOLOv8)
      final resized = img.copyResize(
        image,
        width: 640,
        height: 640,
      );

      // Convert to TensorFlow input format (float32 normalized)
      final input = _imageToByteListFloat32(resized, 640, 640);

      // Prepare output map
      final output = <int, Object>{};
      
      // Run inference - adjust this based on your actual model outputs
      // Most YOLOv8 models output: [1, 25200, 85] for detections
      _interpreter!.runForMultipleInputs([input], output);

      // Parse results
      return _parseYOLOOutput(output);
    } catch (e) {
      print('❌ Inference error: $e');
      rethrow;
    }
  }

  Uint8List _imageToByteListFloat32(
    img.Image image,
    int inputSize,
    int mean,
  ) {
    final convertedBytes = Uint8List(inputSize * inputSize * 3);
    var pixelIndex = 0;

    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        final pixel = image.getPixelSafe(j, i);
        convertedBytes[pixelIndex++] = (pixel.r as int);
        convertedBytes[pixelIndex++] = (pixel.g as int);
        convertedBytes[pixelIndex++] = (pixel.b as int);
      }
    }

    return convertedBytes;
  }

  DetectionResult _parseYOLOOutput(Map<int, Object> output) {
    try {
      // This is a simplified parser - real YOLO output parsing is more complex
      // You'll need to adjust based on your actual model output format
      
      // Example detection result (you should parse actual YOLO detections)
      const fridgeTypes = [
        'French Door',
        'Side-by-Side',
        'Top Freezer',
        'Bottom Freezer',
        'Single Door'
      ];
      
      const possibleItems = [
        'milk',
        'eggs',
        'juice',
        'butter',
        'cheese',
        'vegetables',
        'fruits',
        'meat',
        'yogurt',
        'bread'
      ];

      // Simulated parsing - replace with actual YOLO output parsing
      return DetectionResult(
        fridgeType: fridgeTypes[DateTime.now().millisecond % fridgeTypes.length],
        numDoors: (DateTime.now().millisecond % 3) + 1,
        itemsDetected: possibleItems
            .where((item) => DateTime.now().millisecond % 2 == 0)
            .toList(),
        confidence: 0.85 + (DateTime.now().millisecond % 10) * 0.01,
        rawJson: output.toString(),
      );
    } catch (e) {
      print('❌ Output parsing error: $e');
      // Return default result on error
      return DetectionResult(
        fridgeType: 'Unknown',
        numDoors: 0,
        itemsDetected: [],
        confidence: 0.0,
        rawJson: 'Error: $e',
      );
    }
  }

  // Dispose when done
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
