import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../models/detection_result.dart';
import '../models/gemini_insights.dart';
import '../services/yolo_detection_service.dart';
import '../services/gemini_ai_service.dart';
import 'detection_results_screen.dart';

class CameraDetectionScreen extends StatefulWidget {
  const CameraDetectionScreen({super.key});

  @override
  State<CameraDetectionScreen> createState() => _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends State<CameraDetectionScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;
  String? _statusMessage;
  
  // Throttling logic
  DateTime? _lastGeminiCall;
  DetectionResult? _lastDetection;
  static const Duration _geminiCooldown = Duration(seconds: 15); // Wait 15s between calls

  late YOLODetectionService _yoloService;
  late GeminiAIService _geminiService;

  @override
  void initState() {
    super.initState();
    _yoloService = YOLODetectionService();
    _geminiService = GeminiAIService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  Future<void> _captureAndDetect() async {
    if (_isProcessing || _cameraController == null) return;

    // Check for rate limiting/throttling
    final now = DateTime.now();
    if (_lastGeminiCall != null) {
      final timeSinceLastCall = now.difference(_lastGeminiCall!);
      if (timeSinceLastCall < _geminiCooldown) {
        final waitTime = _geminiCooldown.inSeconds - timeSinceLastCall.inSeconds;
        _showError('Rate limit protection: Please wait $waitTime more seconds.');
        return;
      }
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing image...';
    });

    try {
      // Take photo
      final XFile photo = await _cameraController!.takePicture();
      final File imageFile = File(photo.path);

      if (mounted) {
        setState(() => _statusMessage = '🔍 Analyzing with YOLO...');
      }

      // Run YOLO detection locally (no internet needed)
      final DetectionResult detection =
          await _yoloService.detectFromFile(imageFile);

      // Check if detection items have changed significantly
      if (_lastDetection != null && _isDetectionSame(_lastDetection!, detection)) {
        if (mounted) {
          _showError('No significant changes detected. Skipping Gemini call.');
          setState(() => _isProcessing = false);
        }
        return;
      }

      if (mounted) {
        setState(() => _statusMessage = '🤖 Generating insights with Gemini...');
      }

      // Update timestamp and last detection before calling Gemini
      _lastGeminiCall = DateTime.now();
      _lastDetection = detection;

      // Send ONLY structured text to Gemini (not the image)
      final GeminiInsights insights =
          await _geminiService.generateInsights(detection);

      if (mounted) {
        // Navigate to results screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetectionResultsScreen(
              detection: detection,
              insights: insights,
              imageFile: imageFile,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Detection failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Picking image...';
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final File imageFile = File(pickedFile.path);

      if (mounted) {
        setState(() => _statusMessage = '🔍 Analyzing with YOLO...');
      }

      // Run YOLO detection
      final DetectionResult detection =
          await _yoloService.detectFromFile(imageFile);

      if (mounted) {
        setState(() => _statusMessage = '🤖 Generating insights with Gemini...');
      }

      // Generate Gemini insights
      final GeminiInsights insights =
          await _geminiService.generateInsights(detection);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetectionResultsScreen(
              detection: detection,
              insights: insights,
              imageFile: imageFile,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Gallery pick failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  bool _isDetectionSame(DetectionResult oldResult, DetectionResult newResult) {
    if (oldResult.itemsDetected.length != newResult.itemsDetected.length) return false;
    
    // Sort and compare item lists
    final oldItems = List<String>.from(oldResult.itemsDetected)..sort();
    final newItems = List<String>.from(newResult.itemsDetected)..sort();
    
    for (int i = 0; i < oldItems.length; i++) {
      if (oldItems[i] != newItems[i]) return false;
    }
    
    return true;
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = null;
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _yoloService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Your Fridge')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Your Fridge'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Camera preview
          CameraPreview(_cameraController!),

          // Status overlay
          if (_statusMessage != null)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black87,
                    Colors.black26,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Instructions
                  Text(
                    'Position your fridge in frame and tap to scan',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery button
                      FloatingActionButton(
                        onPressed: _isProcessing ? null : _pickFromGallery,
                        tooltip: 'Pick from gallery',
                        mini: true,
                        backgroundColor: Colors.grey[700],
                        child: const Icon(Icons.photo_library),
                      ),

                      // Capture button (main)
                      FloatingActionButton(
                        onPressed: _isProcessing ? null : _captureAndDetect,
                        backgroundColor: const Color(0xFFFFB6C1),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                      ),

                      // Info button
                      FloatingActionButton(
                        onPressed: _showInfo,
                        tooltip: 'How it works',
                        mini: true,
                        backgroundColor: Colors.grey[700],
                        child: const Icon(Icons.info),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('How Fridge Scanning Works'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 Our Smart Process:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('1️⃣ Camera captures your fridge'),
            Text('2️⃣ YOLO detects items locally (no internet!)'),
            Text('3️⃣ Gemini analyzes & gives smart insights'),
            Text('4️⃣ Get recipes, storage tips & recommendations'),
            SizedBox(height: 10),
            Text(
              '✨ Benefits:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• Fast & offline detection'),
            Text('• Privacy-focused (only text to Gemini)'),
            Text('• Smart recommendations'),
            Text('• No per-request fees'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
