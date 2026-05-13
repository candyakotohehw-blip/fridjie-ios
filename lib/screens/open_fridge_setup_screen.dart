import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:math';
// Gemini AI imports
import 'package:google_generative_ai/google_generative_ai.dart';
// ...existing code...
import 'package:provider/provider.dart';
import '../providers/fridge_provider.dart';
import '../models/fridge_item.dart';
import '../utils/item_illustration.dart';
import '../services/fridge_analysis_service.dart';
import '../models/fridge_setup_models.dart';
import 'shelf_scan_screen.dart';
import 'new_user_dashboard_screen.dart';

enum _Step5Ui { hub, review }

/// Editable rows on Step 5 review (after scan / upload).
class _Step5ReviewLine {
  _Step5ReviewLine({
    required this.name,
    required this.category,
    this.qty = 1,
  });

  String name;
  String category;
  int qty;
}

class OpenFridgeSetupScreen extends StatefulWidget {
  const OpenFridgeSetupScreen({super.key});

  @override
  State<OpenFridgeSetupScreen> createState() => _OpenFridgeSetupScreenState();
}

class _OpenFridgeSetupScreenState extends State<OpenFridgeSetupScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 0;
  bool _isAnalyzing = false;
  DateTime? _lastAnalysisTime;
  double _analysisProgress = 0.0;
  final List<bool> _analysisSteps = [false, false, false];
  bool _didPromptStepTwo = false;
  Uint8List? _selectedImageBytes;
  
  // ML Kit instances
  ObjectDetector? _objectDetector;
  TextRecognizer? _textRecognizer;
  
  // Analysis service
  late FridgeAnalysisService _analysisService;
  FridgeAnalysisResult? _analysisResult;
  
  // API Key
  final String _apiKey = "AIzaSyDDasFFkt7WbS2wUDS711wy8Br208lzIho";
  String _setupMethod = 'Take a Photo';
  
  late final AnimationController _analyzingScanController;
  late final AnimationController _penguinRunController;

  /// In-app camera (first step — take photo flow)
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _flashOn = false;

  // Gemini AI model
  late GenerativeModel _geminiModel;

  // Layout anchors
  Map<String, Alignment> _layoutAnchors = {};

  // Fridge sections
  List<String> _sections = [
    'Left Door',
    'Right Door',
    'Middle Drawer',
    'Upper Drawer',
    'Lower Drawer',
    'Freezer Drawer',
    'Crisper Drawer',
    'Ice Maker',
  ];

  /// User-dragged label positions on Step 4 (photo coordinates, -1..1).
  final Map<int, Alignment> _layoutChipAlignment = {};
  int? _layoutChipDragIndex;
  Alignment? _layoutChipDragOrigin;
  Offset _layoutChipDragAccum = Offset.zero;

  /// Step 5: which fridge zone items are added to (defaults when entering Step 5).
  int? _addItemsZoneIndex;

  _Step5Ui _step5Ui = _Step5Ui.hub;
  final List<ShelfScanItem> _shelfScannedItems = [];
  final List<_Step5ReviewLine> _step5ReviewLines = [];
  bool _step5ReviewContinueEnabled = false;
  Uint8List? _shelfReviewImageBytes;

  static const _step5QuickChips = <(String emoji, String label, String cat)>[
    ('🥛', 'Yogurt', 'Dairy'),
    ('🥛', 'Milk', 'Dairy'),
    ('🥤', 'Drinks', 'Beverages'),
    ('🧈', 'Butter', 'Dairy'),
    ('🍱', 'Leftovers', 'Meals'),
  ];

  @override
  void initState() {
    super.initState();
    _analyzingScanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _penguinRunController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..repeat(reverse: true);
    _analysisService = FridgeAnalysisService(apiKey: _apiKey);
    _initializeDetector();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_setupMethod == 'Take a Photo') {
        _initEmbeddedCamera();
      } else if (_setupMethod == 'Upload from Gallery') {
        _triggerPickerForMethod();
      }
    });
  }
  
  void _initializeLayoutAnchors() {
    // French Door Layout (most common)
    _layoutAnchors = {
      'LEFT FRENCH DOOR': const Alignment(-0.35, -0.35),
      'RIGHT FRENCH DOOR': const Alignment(0.35, -0.35),
      'LEFT DOOR': const Alignment(-0.35, -0.35),
      'RIGHT DOOR': const Alignment(0.35, -0.35),
      'MIDDLE DRAWER': const Alignment(0.0, 0.15),
      'UPPER DRAWER': const Alignment(0.0, -0.05),
      'LOWER DRAWER': const Alignment(0.0, 0.35),
      'BOTTOM FREEZER DRAWER': const Alignment(0.0, 0.65),
      'FREEZER DRAWER': const Alignment(0.0, 0.65),
      'CRISPER DRAWER': const Alignment(0.0, 0.5),
      'ICE MAKER': const Alignment(0.4, 0.55),
    };
  }
  
  String _cleanLabel(String label) {
    return label
        .replaceAll(RegExp(r'[_-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
  }

  void _initializeDetector() {
    // Standard Object Detection options using Google's base model
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    // Use the most stable Gemini model
    _geminiModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
    );
  }

  Future<void> _checkApiModels() async {
    // 🚀 NEW API KEY DIAGNOSTICS
    // Only test the most stable model
    const String stableModel = 'gemini-2.0-flash';
    try {
      debugPrint("Testing Gemini Model: $stableModel...");
      final testModel = GenerativeModel(
        model: stableModel,
        apiKey: _apiKey,
      );
      final response = await testModel.generateContent([Content.text("hi")]);
      if (response.text != null) {
        debugPrint("✅ SUCCESS: $stableModel is active and working!");
        setState(() {
          _geminiModel = testModel;
        });
        return;
      }
    } catch (e) {
      debugPrint("❌ FAILED: $stableModel - $e");
    }
  }

  @override
  void dispose() {
    _disposeEmbeddedCamera();
    _objectDetector?.close();
    _textRecognizer?.close();
    _pageController.dispose();
    _analyzingScanController.dispose();
    _penguinRunController.dispose();
    super.dispose();
  }

  Future<void> _disposeEmbeddedCamera() async {
    final c = _cameraController;
    _cameraController = null;
    _cameraReady = false;
    _flashOn = false;
    if (c != null) {
      try {
        if (c.value.isInitialized) {
          await c.setFlashMode(FlashMode.off);
        }
      } catch (_) {}
      await c.dispose();
    }
  }

  void _nextStep() {
    if (_currentStep >= 5) return;
    if (_currentStep == 0 && _setupMethod == 'Take a Photo') {
      _disposeEmbeddedCamera();
    }
    final leavingLayout = _currentStep == 3;
    setState(() {
      _currentStep += 1;
      if (leavingLayout) {
        _addItemsZoneIndex ??= 0;
        _step5Ui = _Step5Ui.hub;
        _shelfScannedItems.clear();
        _step5ReviewLines.clear();
        _step5ReviewContinueEnabled = false;
        _shelfReviewImageBytes = null;
      }
    });
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _prevStep() {
    if (_currentStep == 4 && _step5Ui == _Step5Ui.review) {
      setState(() {
        _step5Ui = _Step5Ui.hub;
        _step5ReviewContinueEnabled = false;
      });
      return;
    }
    if (_currentStep <= 0) {
      _disposeEmbeddedCamera();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _currentStep -= 1);
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
    if (_currentStep == 0 && _setupMethod == 'Take a Photo') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initEmbeddedCamera();
      });
    }
  }

  Future<void> _initEmbeddedCamera() async {
    if (_setupMethod != 'Take a Photo') return;
    if (_cameraController?.value.isInitialized ?? false) return;
    await _disposeEmbeddedCamera();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty || !mounted) return;
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setFlashMode(FlashMode.off);
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _flashOn = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start camera: $e')),
      );
    }
  }

  Future<void> _toggleFlash() async {
    final c = _cameraController;
    if (c == null || !c.value.isInitialized) return;
    try {
      final next = _flashOn ? FlashMode.off : FlashMode.torch;
      await c.setFlashMode(next);
      if (mounted) setState(() => _flashOn = !_flashOn);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash not available on this device.')),
      );
    }
  }

  Future<void> _captureFromEmbeddedCamera() async {
    final c = _cameraController;
    if (c == null || !c.value.isInitialized) return;
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _analysisResult = null;
      });
      await _disposeEmbeddedCamera();
      if (mounted && _currentStep == 0) {
        _nextStep();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
    }
  }

  void _triggerPickerForMethod() async {
    if (_didPromptStepTwo) return;
    _didPromptStepTwo = true;
    // "Take a Photo" uses embedded camera on first step — no native picker here.
    if (_setupMethod == 'Upload from Gallery') {
      await _pickImage(ImageSource.gallery);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _analysisResult = null; // Reset analysis when new image is picked
      });

      // Auto-slide to next step after a short delay to show the checkmark
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted && _currentStep == 0) {
        _nextStep();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Could not open camera.'
                : 'Could not open gallery.',
          ),
        ),
      );
    }
  }

  DateTime? _lastAnalyze;
  Future<void> _startAnalyzing() async {
    if (_isAnalyzing) return;
    
    // Safety lock: already analyzed this image?
    if (_analysisResult != null) {
      _nextStep();
      return;
    }
    
    // Cooldown: 15 seconds
    if (_lastAnalyze != null && DateTime.now().difference(_lastAnalyze!).inSeconds < 15) {
      final wait = 15 - DateTime.now().difference(_lastAnalyze!).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please wait ${wait}s before analyzing again'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    _isAnalyzing = true;
    _lastAnalyze = DateTime.now();
    setState(() {
      _analysisProgress = 0.0;
      _analysisSteps[0] = false;
      _analysisSteps[1] = false;
      _analysisSteps[2] = false;
    });
    if (_selectedImageBytes == null) {
      _isAnalyzing = false;
      return;
    }
    try {
      print("CALLING GEMINI");
      final base64Image = base64Encode(_selectedImageBytes!);
      final aiData = await _analysisService.analyzeFridgeImage(
        base64Image,
        onProgress: (progress) => setState(() => _analysisProgress = progress),
        onStepComplete: (step) => setState(() => _analysisSteps[step] = true),
      );
      _analysisResult = FridgeAnalysisResult.fromJson(aiData);
      
      // Dynamically update sections based on AI detection for Step 6
      if (_analysisResult != null && _analysisResult!.sections.isNotEmpty) {
        setState(() {
          _sections = List<String>.from(_analysisResult!.sections);
          _layoutChipAlignment.clear();
        });
      }
      
      setState(() {});
      // Move to confirmation step
      if (mounted && _currentStep == 1) {
        _nextStep();
      }
    } catch (e) {
      debugPrint("Analysis Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Analysis failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isAnalyzing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2D7DFF);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool embeddedCameraStep =
        _currentStep == 0 && _setupMethod == 'Take a Photo';
    final bool analyzingStep = _currentStep == 1;
    final bool confirmDetailsStep = _currentStep == 2;
    final bool layoutEditStep = _currentStep == 3;
    final bool addItemsPickStep = _currentStep == 4;
    final bool addItemsHubStep = _currentStep == 5;

    final PreferredSizeWidget appBar;
    if (embeddedCameraStep) {
      appBar = AppBar(
              backgroundColor: cs.surface,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF1A2B4D), size: 20),
                onPressed: _prevStep,
              ),
              centerTitle: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/img.png', height: 28),
                  const SizedBox(width: 6),
                  const Text(
                    'Friji',
                    style: TextStyle(
                      color: Color(0xFF2D7DFF),
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.help_outline_rounded,
                      color: Colors.grey.shade700, size: 24),
                  onPressed: _showFridgeCaptureHelp,
                ),
              ],
            );
    } else if (addItemsPickStep) {
      final z = _sections[(_addItemsZoneIndex ?? 0).clamp(0, _sections.length - 1)];
      final zoneHint = z.toLowerCase();
      if (_step5Ui == _Step5Ui.review) {
        appBar = AppBar(
          backgroundColor: cs.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
            child: Material(
              color: const Color(0xFFE8F1FF),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _prevStep,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: primaryBlue,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/img.png', height: 26),
              const SizedBox(width: 6),
              const Text(
                'Friji',
                style: TextStyle(
                  color: Color(0xFF2D7DFF),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: Text('🐧✨', style: TextStyle(fontSize: 26))),
            ),
          ],
        );
      } else {
        appBar = AppBar(
          backgroundColor: cs.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
            child: Material(
              color: const Color(0xFFE8F1FF),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _prevStep,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: primaryBlue,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.view_stream_rounded,
                      color: Color(0xFF2D7DFF), size: 22),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Add to $z',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A2B4D),
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Items added here will appear on your $zoneHint.',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.45),
                ),
              ),
            ],
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 10),
              child: Center(child: Text('🐧', style: TextStyle(fontSize: 30))),
            ),
          ],
        );
      }
    } else if (analyzingStep ||
        confirmDetailsStep ||
        layoutEditStep ||
        addItemsHubStep) {
      appBar = AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
          child: Material(
            color: const Color(0xFFE8F1FF),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: (analyzingStep && _isAnalyzing) ? null : _prevStep,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: primaryBlue,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/img.png', height: 28),
            const SizedBox(width: 6),
            const Text(
              'Friji',
              style: TextStyle(
                color: Color(0xFF2D7DFF),
                fontWeight: FontWeight.w900,
                fontSize: 22,
                fontStyle: FontStyle.italic,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );
    } else {
      appBar = AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black87,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'My Fridge',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            );
    }

    return Scaffold(
      backgroundColor: (embeddedCameraStep ||
              analyzingStep ||
              confirmDetailsStep ||
              layoutEditStep ||
              addItemsPickStep ||
              addItemsHubStep)
          ? cs.surface
          : (isDark ? cs.surface : const Color(0xFFF4F7FC)),
      appBar: appBar,
      body: Column(
        children: [
          _FridgeSetupLabeledStepper(currentStep: _currentStep),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStepTwo(),
                _buildStepThree(),
                _buildStepThreeConfirmation(),
                _buildStepFour(),
                _buildStepFive(),
                _buildStepSix(),
              ],
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  void _showFridgeCaptureHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tips for a great photo'),
        content: const Text(
          'Stand back so the whole fridge fits in the frame.\n\n'
          'Use good lighting and avoid glare on stainless steel.\n\n'
          'Keep doors closed unless you want to map the interior.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwo() {
    if (_setupMethod == 'Take a Photo') {
      return _buildStepTakePhotoEmbedded();
    }
    if (_setupMethod == 'Upload from Gallery') {
      return _buildStepGalleryPick();
    }
    return _buildStepManualIntro();
  }

  /// Live in-app camera (matches product mock).
  Widget _buildStepTakePhotoEmbedded() {
    const primaryBlue = Color(0xFF2D7DFF);
    const titleColor = Color(0xFF1A2B4D);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Take a photo of your fridge',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Make sure the entire fridge is visible',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.45),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryBlue.withOpacity(0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🐧', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A clear photo helps us detect your fridge model accurately.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Colors.black.withOpacity(0.65),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Colors.black,
                    child: _cameraReady &&
                            _cameraController != null &&
                            _cameraController!.value.isInitialized
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              final c = _cameraController!;
                              return ClipRect(
                                child: OverflowBox(
                                  alignment: Alignment.center,
                                  maxWidth: constraints.maxWidth * 1.15,
                                  maxHeight: constraints.maxHeight * 1.15,
                                  child: CameraPreview(c),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 2,
                            ),
                          ),
                  ),
                  // Corner brackets (object framing)
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ViewfinderPainter(),
                      ),
                    ),
                  ),
                  // Floating tip
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              color: Colors.amber.shade200, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tip: Stand back and make sure the fridge fits within the frame.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _roundCamControl(
                icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                onTap: _toggleFlash,
              ),
              GestureDetector(
                onTap: _captureFromEmbeddedCamera,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              _roundCamControl(
                icon: Icons.photo_library_outlined,
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundCamControl({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _buildStepGalleryPick() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload a fridge photo',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2B4D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a clear photo from your gallery.',
            style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.55)),
          ),
          const Spacer(),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Open gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D7DFF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildStepManualIntro() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manual setup',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2B4D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You chose to set up your fridge manually. Tap Continue to pick your layout and sections.',
            style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.55)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepThree() {
    const primaryBlue = Color(0xFF2D7DFF);
    const navy = Color(0xFF1A2B4D);
    final hasImage = _selectedImageBytes != null;
    final progress = _analysisProgress.clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final scanStrength = _isAnalyzing ? 1.0 : 0.2;
    final maxCardW = min(
      MediaQuery.sizeOf(context).width - 56,
      300.0,
    );
    final photoStack = SizedBox(
      width: maxCardW + 56,
      height: maxCardW * (4 / 3) + 64,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 2,
            left: 6,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 11,
              color: const Color(0xFF9EC0FF).withOpacity(0.95),
            ),
          ),
          Positioned(
            top: 40,
            right: 2,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 10,
              color: const Color(0xFF9EC0FF).withOpacity(0.95),
            ),
          ),
          Positioned(
            bottom: 72,
            left: 0,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 9,
              color: const Color(0xFF9EC0FF).withOpacity(0.95),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 8,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 11,
              color: const Color(0xFF9EC0FF).withOpacity(0.95),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 9,
              color: const Color(0xFF9EC0FF).withOpacity(0.7),
            ),
          ),
          Container(
            width: maxCardW + 20,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.grey.shade200,
                      child: hasImage
                          ? Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Icon(
                                Icons.kitchen_rounded,
                                size: 56,
                                color: Colors.black26,
                              ),
                            ),
                    ),
                    if (scanStrength > 0)
                      AnimatedBuilder(
                        animation: _analyzingScanController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _AnalyzingScanBandPainter(
                              t: _analyzingScanController.value,
                              strength: scanStrength,
                            ),
                          );
                        },
                      ),
                    IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: const [
                            Positioned(
                              left: 0,
                              top: 0,
                              child: _AnalyzingBlueBracket(quarterTurns: 0),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: _AnalyzingBlueBracket(quarterTurns: 1),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: _AnalyzingBlueBracket(quarterTurns: 2),
                            ),
                            Positioned(
                              left: 0,
                              bottom: 0,
                              child: _AnalyzingBlueBracket(quarterTurns: 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: photoStack,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '✨ AI is on it',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: navy.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Identifying your fridge model...',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: navy,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Friji is analyzing the details to find the exact model of your fridge.',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: Colors.black.withOpacity(0.48),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackW = constraints.maxWidth;
              final travel = (trackW - 52).clamp(0.0, double.infinity);
              final dx = progress * travel;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 52,
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          [_penguinRunController, _analyzingScanController]),
                      builder: (context, child) {
                        final run = _penguinRunController.value;
                        final hop = sin(run * pi) *
                            (_isAnalyzing ? 7.0 : 2.2);
                        final tilt = (run - 0.5) *
                            (_isAnalyzing ? 0.18 : 0.06);
                        final squash = 1.0 +
                            (_isAnalyzing ? 0.06 * sin(run * pi) : 0.02);
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: dx.clamp(0.0, travel),
                              bottom: 0,
                              child: Transform.translate(
                                offset: Offset(0, -hop),
                                child: Transform.rotate(
                                  angle: tilt,
                                  alignment: Alignment.bottomCenter,
                                  child: Transform.scale(
                                    scale: squash,
                                    alignment: Alignment.bottomCenter,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (_isAnalyzing)
                                          _penguinSpeedStreaks(
                                              primaryBlue, run),
                                        const Text(
                                          '🐧',
                                          style: TextStyle(fontSize: 40),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 12,
                        width: trackW,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4E8FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress <= 0 ? 0 : progress,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                colors: [
                                  primaryBlue,
                                  primaryBlue.withOpacity(0.88),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left:
                            (progress * trackW - 7).clamp(0.0, trackW - 14),
                        top: -5,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: primaryBlue, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.55),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$pct%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _penguinSpeedStreaks(Color primaryBlue, double phase) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 2),
      child: Opacity(
        opacity: 0.45 + 0.45 * sin(phase * pi),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (i) {
            final t = (phase + i * 0.18) % 1.0;
            return Container(
              margin: const EdgeInsets.only(right: 2),
              width: 3,
              height: 3 + t * 14,
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.2 + t * 0.45),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.25),
                    blurRadius: 3,
                    offset: const Offset(-1, 0),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  void _goToCaptureFromConfirmation() {
    setState(() {
      _currentStep = 0;
      _selectedImageBytes = null;
      _analysisResult = null;
      _didPromptStepTwo = false;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_setupMethod == 'Take a Photo') {
        _initEmbeddedCamera();
      } else if (_setupMethod == 'Upload from Gallery') {
        _didPromptStepTwo = false;
        _pickImage(ImageSource.gallery);
      }
    });
  }

  Future<void> _showEditFridgeDetailsDialog() async {
    final r = _analysisResult;
    if (r == null || !mounted) return;

    final brandC = TextEditingController(text: r.brand);
    final modelC = TextEditingController(text: r.model);
    final colorC = TextEditingController(text: r.color);
    final typeC = TextEditingController(text: r.type);
    final capC = TextEditingController(text: r.capacity);
    final dimC = TextEditingController(text: r.dimensions);

    String clean(String s) {
      final t = s.trim();
      return t.isEmpty ? 'Unknown' : t;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: brandC,
                decoration: const InputDecoration(labelText: 'Brand'),
                textCapitalization: TextCapitalization.words,
              ),
              TextField(
                controller: modelC,
                decoration: const InputDecoration(
                  labelText: 'Model (exact code if known)',
                ),
              ),
              TextField(
                controller: colorC,
                decoration: const InputDecoration(labelText: 'Color'),
              ),
              TextField(
                controller: typeC,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextField(
                controller: capC,
                decoration: const InputDecoration(labelText: 'Capacity'),
              ),
              TextField(
                controller: dimC,
                decoration: const InputDecoration(
                  labelText: 'Dimensions (W x H x D mm)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              brandC.dispose();
              modelC.dispose();
              colorC.dispose();
              typeC.dispose();
              capC.dispose();
              dimC.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _analysisResult = r.copyWith(
                  brand: clean(brandC.text),
                  model: clean(modelC.text),
                  color: clean(colorC.text),
                  type: clean(typeC.text),
                  capacity: clean(capC.text),
                  dimensions: clean(dimC.text),
                );
              });
              brandC.dispose();
              modelC.dispose();
              colorC.dispose();
              typeC.dispose();
              capC.dispose();
              dimC.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _confirmDetailsSpecRow({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    const accent = Color(0xFF4A90E2);
    final display = value.trim().isEmpty || value == 'Unknown' ? '—' : value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.42),
                  height: 1.05,
                ),
              ),
              Text(
                display,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2B4D),
                  height: 1.2,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepThreeConfirmation() {
    const primaryBlue = Color(0xFF2D7DFF);
    const panelBlue = Color(0xFF4A90E2);
    const navy = Color(0xFF1A2B4D);
    final r = _analysisResult;

    final cardCore = Container(
      width: double.infinity,
      height: 268,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: Colors.grey.shade100,
                      child: _selectedImageBytes != null
                          ? Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : const Icon(Icons.kitchen_rounded,
                              size: 48, color: Colors.black12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _goToCaptureFromConfirmation,
                  icon: Icon(Icons.photo_camera_outlined,
                      size: 16, color: panelBlue),
                  label: const Text(
                    'Retake Photo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: panelBlue,
                    side: BorderSide(color: panelBlue.withOpacity(0.55)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF34C759).withOpacity(0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Color(0xFF34C759), size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Model Detected',
                        style: TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _confirmDetailsSpecRow(
                        icon: Icons.storefront_outlined,
                        label: 'Brand',
                        value: r?.brand ?? 'Unknown',
                      ),
                      _confirmDetailsSpecRow(
                        icon: Icons.article_outlined,
                        label: 'Model',
                        value: r?.model ?? 'Unknown',
                        maxLines: 2,
                      ),
                      _confirmDetailsSpecRow(
                        icon: Icons.palette_outlined,
                        label: 'Color',
                        value: r?.color ?? 'Unknown',
                      ),
                      _confirmDetailsSpecRow(
                        icon: Icons.kitchen_outlined,
                        label: 'Type',
                        value: r?.type ?? 'Unknown',
                      ),
                      _confirmDetailsSpecRow(
                        icon: Icons.scale_outlined,
                        label: 'Capacity',
                        value: r?.capacity ?? 'Unknown',
                      ),
                      _confirmDetailsSpecRow(
                        icon: Icons.straighten_outlined,
                        label: 'Dimensions',
                        value: r?.dimensions ?? 'Unknown',
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryBlue.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🐧', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: navy.withOpacity(0.78),
                  fontWeight: FontWeight.w600,
                ),
                children: const [
                  TextSpan(text: 'Looks right? Let\'s confirm and move to '),
                  TextSpan(
                    text: '✨',
                    style: TextStyle(fontSize: 13),
                  ),
                  TextSpan(
                    text:
                        ' the next step to set up the inside of your fridge.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _nextStep,
          icon: const Icon(Icons.check_rounded, size: 20),
          label: const Text(
            'Yes, this is my fridge',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _goToCaptureFromConfirmation,
          icon: Icon(Icons.refresh_rounded, size: 18, color: panelBlue),
          label: Text(
            'No, try again',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: panelBlue,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: BorderSide(color: panelBlue.withOpacity(0.65)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showEditFridgeDetailsDialog,
          icon: Icon(Icons.edit_outlined, size: 18, color: panelBlue),
          label: Text(
            'Edit details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: panelBlue,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: BorderSide(color: panelBlue.withOpacity(0.65)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 16, color: panelBlue.withOpacity(0.85)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'We found your fridge!',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: navy,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Friji has identified your fridge model. Please review the details below.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.48),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.auto_awesome_rounded,
                  size: 14, color: panelBlue.withOpacity(0.65)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: min(MediaQuery.sizeOf(context).width - 32, 400),
                height: 356,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    cardCore,
                    const SizedBox(height: 10),
                    banner,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          actions,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4A90E2), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactDetailItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4A90E2), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _nameLooksLeftSide(String raw) {
    final s = raw.toLowerCase();
    return s.contains('left') ||
        s.contains(' lh') ||
        s.contains('l.h.') ||
        s.contains('l door');
  }

  static bool _nameLooksRightSide(String raw) {
    final s = raw.toLowerCase();
    return s.contains('right') ||
        s.contains(' rh') ||
        s.contains('r.h.') ||
        s.contains('r door');
  }

  static final RegExp _wordDoor = RegExp(r'\bdoor\b', caseSensitive: false);

  static bool _nameLooksDoorRelated(String raw) {
    final low = raw.toLowerCase();
    if (_wordDoor.hasMatch(low)) return true;
    return low.contains('door shelf') ||
        low.contains('door bin') ||
        low.contains('door-shelf');
  }

  static double _cavityYFromName(String raw, int orderIndex, int total) {
    final low = raw.toLowerCase();
    if (low.contains('ice') ||
        low.contains('dispenser') ||
        low.contains('water')) {
      return -0.38;
    }
    if (low.contains('top') ||
        low.contains('upper') ||
        low.contains('high')) {
      return -0.42;
    }
    if (low.contains('middle') ||
        low.contains('mid ') ||
        low.contains('center')) {
      return -0.08;
    }
    if (low.contains('crisper') ||
        low.contains('vegetable') ||
        low.contains('veg ')) {
      return 0.34;
    }
    if (low.contains('drawer') && !low.contains('freezer')) {
      return 0.26;
    }
    if (low.contains('bottom') && !low.contains('freezer')) {
      return 0.16;
    }
    if (total <= 1) return -0.05;
    final t = orderIndex / (total - 1);
    return -0.36 + t * 0.62;
  }

  void _reindexLayoutChipAlignmentAfterRemove(int removedIndex) {
    final next = <int, Alignment>{};
    _layoutChipAlignment.forEach((k, v) {
      if (k < removedIndex) {
        next[k] = v;
      } else if (k > removedIndex) {
        next[k - 1] = v;
      }
    });
    _layoutChipAlignment
      ..clear()
      ..addAll(next);
  }

  List<_LayoutZoneSlot> _computeLayoutSlots() {
    final n = _sections.length;
    final slots = <_LayoutZoneSlot>[];
    final freezerIdx = <int>[];
    final leftDoorIdx = <int>[];
    final rightDoorIdx = <int>[];
    final neutralDoorIdx = <int>[];
    final cavityIdx = <int>[];

    for (var i = 0; i < n; i++) {
      final name = _sections[i];
      final low = name.toLowerCase();
      if (low.contains('freezer')) {
        freezerIdx.add(i);
        continue;
      }
      if (_nameLooksDoorRelated(name)) {
        if (_nameLooksLeftSide(name)) {
          leftDoorIdx.add(i);
        } else if (_nameLooksRightSide(name)) {
          rightDoorIdx.add(i);
        } else {
          neutralDoorIdx.add(i);
        }
        continue;
      }
      cavityIdx.add(i);
    }

    if (neutralDoorIdx.length == 2) {
      leftDoorIdx.add(neutralDoorIdx[0]);
      rightDoorIdx.add(neutralDoorIdx[1]);
      neutralDoorIdx.clear();
    } else if (neutralDoorIdx.length > 2) {
      for (var k = 0; k < neutralDoorIdx.length; k++) {
        if (k.isEven) {
          leftDoorIdx.add(neutralDoorIdx[k]);
        } else {
          rightDoorIdx.add(neutralDoorIdx[k]);
        }
      }
      neutralDoorIdx.clear();
    }

    var palette = 0;

    void addVerticalColumn(
      List<int> indices,
      double x,
      bool isDoor,
      bool isFreezer,
    ) {
      for (var j = 0; j < indices.length; j++) {
        final t = indices.length <= 1 ? 0.5 : j / (indices.length - 1);
        final y = -0.44 + t * 0.82;
        slots.add(_LayoutZoneSlot(
          sectionIndex: indices[j],
          alignment: Alignment(x, y),
          isDoor: isDoor,
          isFreezer: isFreezer,
          paletteIndex: palette++,
        ));
      }
    }

    for (var j = 0; j < freezerIdx.length; j++) {
      slots.add(_LayoutZoneSlot(
        sectionIndex: freezerIdx[j],
        alignment: Alignment(0, 0.74 + j * 0.06),
        isDoor: false,
        isFreezer: true,
        paletteIndex: 0,
      ));
    }

    for (var j = 0; j < cavityIdx.length; j++) {
      final idx = cavityIdx[j];
      final y = _cavityYFromName(_sections[idx], j, cavityIdx.length);
      slots.add(_LayoutZoneSlot(
        sectionIndex: idx,
        alignment: Alignment(0.06, y),
        isDoor: false,
        isFreezer: false,
        paletteIndex: palette++,
      ));
    }

    addVerticalColumn(leftDoorIdx, -0.66, true, false);
    addVerticalColumn(rightDoorIdx, 0.66, true, false);

    for (var j = 0; j < neutralDoorIdx.length; j++) {
      final t = neutralDoorIdx.length <= 1 ? 0.5 : j / (neutralDoorIdx.length - 1);
      final y = -0.42 + t * 0.78;
      slots.add(_LayoutZoneSlot(
        sectionIndex: neutralDoorIdx[j],
        alignment: Alignment(0, y),
        isDoor: true,
        isFreezer: false,
        paletteIndex: palette++,
      ));
    }

    slots.sort((a, b) {
      int layer(_LayoutZoneSlot s) {
        if (s.isFreezer) return 0;
        if (!s.isDoor) return 1;
        return 2;
      }

      final la = layer(a);
      final lb = layer(b);
      if (la != lb) return la.compareTo(lb);
      return a.sectionIndex.compareTo(b.sectionIndex);
    });

    return slots;
  }

  String _summaryCapacityTypeLine() {
    final r = _analysisResult;
    if (r == null) return 'Detected layout';
    final cap = r.capacity;
    final typ = r.type;
    if (cap == 'Unknown' && typ == 'Unknown') return 'Layout from photo';
    if (cap == 'Unknown') return typ;
    if (typ == 'Unknown') return cap;
    return '$cap • $typ';
  }

  void _appendLayoutSection(String prefix) {
    setState(() {
      var k = 1;
      var label = prefix;
      while (_sections.contains(label)) {
        k++;
        label = '$prefix $k';
      }
      _sections.add(label);
    });
  }

  void _removeLastLayoutSection() {
    if (_sections.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least two zones in your layout.')),
      );
      return;
    }
    setState(() {
      final removed = _sections.length - 1;
      _sections.removeLast();
      _reindexLayoutChipAlignmentAfterRemove(removed);
    });
  }

  void _showViewModelFromLayout() {
    final r = _analysisResult;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fridge model'),
        content: SingleChildScrollView(
          child: r == null
              ? const Text('No analysis data.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogKv('Brand', r.brand),
                    _dialogKv('Model', r.model),
                    _dialogKv('Type', r.type),
                    _dialogKv('Capacity', r.capacity),
                    _dialogKv('Color', r.color),
                    _dialogKv('Dimensions', r.dimensions),
                    _dialogKv('Layout (AI)', r.layoutType),
                    const SizedBox(height: 8),
                    Text(
                      'Zones (${_sections.length}): ${_sections.join(', ')}',
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _dialogKv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          Text(
            v,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2B4D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _layoutZoneChip(_LayoutZoneSlot slot, Size stackSize) {
    const fills = [
      Color(0xFFD9ECFF),
      Color(0xFFDFF5E4),
      Color(0xFFFFF3CD),
      Color(0xFFE8E0FF),
    ];
    final bg = slot.isFreezer
        ? const Color(0xFFF2F4F8)
        : fills[slot.paletteIndex % fills.length];
    final label = _sections[slot.sectionIndex];
    final effective =
        _layoutChipAlignment[slot.sectionIndex] ?? slot.alignment;

    Widget chipFace(Color bgColor) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.drag_indicator_rounded,
              size: 15,
              color: Colors.black.withOpacity(0.38),
            ),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2B4D),
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _renameSection(slot.sectionIndex),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: const Color(0xFF4A90E2).withOpacity(0.95),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: effective,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) {
          _layoutChipDragIndex = slot.sectionIndex;
          _layoutChipDragOrigin =
              _layoutChipAlignment[slot.sectionIndex] ?? slot.alignment;
          _layoutChipDragAccum = Offset.zero;
        },
        onPanUpdate: (details) {
          if (_layoutChipDragIndex != slot.sectionIndex) return;
          final w = stackSize.width.clamp(1.0, double.infinity);
          final h = stackSize.height.clamp(1.0, double.infinity);
          _layoutChipDragAccum += Offset(
            2 * details.delta.dx / w,
            2 * details.delta.dy / h,
          );
          final origin = _layoutChipDragOrigin!;
          setState(() {
            _layoutChipAlignment[slot.sectionIndex] = Alignment(
              (origin.x + _layoutChipDragAccum.dx).clamp(-1.0, 1.0),
              (origin.y + _layoutChipDragAccum.dy).clamp(-1.0, 1.0),
            );
          });
        },
        onPanEnd: (_) {
          if (_layoutChipDragIndex == slot.sectionIndex) {
            _layoutChipDragIndex = null;
            _layoutChipDragOrigin = null;
            _layoutChipDragAccum = Offset.zero;
          }
        },
        onPanCancel: () {
          if (_layoutChipDragIndex == slot.sectionIndex) {
            _layoutChipDragIndex = null;
            _layoutChipDragOrigin = null;
            _layoutChipDragAccum = Offset.zero;
          }
        },
        child: Material(
          color: Colors.transparent,
          child: chipFace(bg),
        ),
      ),
    );
  }

  Widget _editLayoutModelSummaryCard() {
    const panelBlue = Color(0xFF4A90E2);
    final r = _analysisResult;
    final brand = r?.brand ?? '—';
    final model = r?.model ?? '—';
    final pill = _summaryCapacityTypeLine();
    final inferredPanels = r?.refrigeratorDoorPanelCount ??
        (r != null
            ? FridgeAnalysisService.inferRefrigeratorDoorPanelCount(
                r.type, r.layoutType)
            : 0);
    final swingDoorZones = _sections
        .where((s) =>
            RegExp(r'\bdoor\b', caseSensitive: false).hasMatch(s) &&
            !s.toLowerCase().contains('drawer'))
        .length;
    final fz = r?.freezerAccessStyle?.replaceAll('_', ' ');
    final String doorHint;
    if (inferredPanels >= 1) {
      doorHint =
          '$inferredPanels fresh-food door${inferredPanels == 1 ? '' : 's'}'
          '${fz != null && fz.isNotEmpty ? ' • Freezer: $fz' : ''}';
    } else if (swingDoorZones > 0) {
      doorHint =
          '$swingDoorZones door zone${swingDoorZones == 1 ? '' : 's'} from layout';
    } else {
      doorHint = r?.layoutType ?? 'Layout';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 60,
              child: _selectedImageBytes != null
                  ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                  : ColoredBox(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.kitchen_rounded, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A2B4D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  model,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.55),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pill,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        doorHint,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D7DFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _showViewModelFromLayout,
            icon: Icon(Icons.visibility_outlined,
                size: 16, color: panelBlue.withOpacity(0.9)),
            label: Text(
              'View model',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: panelBlue.withOpacity(0.95),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editLayoutSidebarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? foreground,
  }) {
    final fg = foreground ?? const Color(0xFF4A90E2);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepFour() {
    const primaryBlue = Color(0xFF2D7DFF);
    const panelBlue = Color(0xFF4A90E2);
    final slots = _computeLayoutSlots();

    return SizedBox.expand(
      child: ColoredBox(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : const Color(0xFFF4F7FC),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _editLayoutModelSummaryCard(),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 18, color: panelBlue.withOpacity(0.85)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Edit your fridge layout',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A2B4D),
                        height: 1.15,
                      ),
                    ),
                  ),
                  Icon(Icons.auto_awesome_rounded,
                      size: 15, color: panelBlue.withOpacity(0.65)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                    'Drag labels on the photo to place them; tap the pencil to rename.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.48),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.black.withOpacity(0.06)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final sz = constraints.biggest;
                              return Stack(
                                fit: StackFit.expand,
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: _selectedImageBytes != null
                                          ? Image.memory(
                                              _selectedImageBytes!,
                                              fit: BoxFit.contain,
                                            )
                                          : Image.asset(
                                              'sampleui/6.jpg',
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  ColoredBox(
                                                color: Colors.grey.shade200,
                                                child: Icon(
                                                  Icons.kitchen_rounded,
                                                  size: 64,
                                                  color: Colors.grey.shade400,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  for (final s in slots)
                                    _layoutZoneChip(s, sz),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: min(
                          MediaQuery.sizeOf(context).width * 0.30, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Add or Edit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.black.withOpacity(0.78),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap a label to rename, or add zones.',
                            style: TextStyle(
                              fontSize: 9.5,
                              height: 1.25,
                              color: Colors.black.withOpacity(0.45),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView(
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.zero,
                              children: [
                                _editLayoutSidebarButton(
                                  icon: Icons.view_stream_outlined,
                                  label: 'Add Shelf',
                                  onTap: () =>
                                      _appendLayoutSection('Shelf'),
                                ),
                                const SizedBox(height: 6),
                                _editLayoutSidebarButton(
                                  icon: Icons.inbox_outlined,
                                  label: 'Add Drawer',
                                  onTap: () =>
                                      _appendLayoutSection('Drawer'),
                                ),
                                const SizedBox(height: 6),
                                _editLayoutSidebarButton(
                                  icon: Icons.door_front_door_outlined,
                                  label: 'Add Door Shelf',
                                  onTap: () =>
                                      _appendLayoutSection('Door shelf'),
                                ),
                                const SizedBox(height: 6),
                                _editLayoutSidebarButton(
                                  icon: Icons.grid_view_outlined,
                                  label: 'Add Compartment',
                                  onTap: () =>
                                      _appendLayoutSection('Compartment'),
                                ),
                                const SizedBox(height: 10),
                                _editLayoutSidebarButton(
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Remove',
                                  foreground: const Color(0xFFE53935),
                                  onTap: _removeLastLayoutSection,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_outlined,
                        size: 18, color: Colors.black.withOpacity(0.35)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Drag labels to match your photo. Tap ✎ to rename a zone.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _nextStep,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mergeScannedItemsIntoShelf(List<ShelfScanItem> found) {
    for (final f in found) {
      final idx = _shelfScannedItems.indexWhere(
        (e) => e.name.toLowerCase() == f.name.toLowerCase(),
      );
      if (idx < 0) {
        _shelfScannedItems.add(f);
      }
    }
  }

  void _applyScanToReviewLines(List<ShelfScanItem> found) {
    _step5ReviewLines
      ..clear()
      ..addAll(
        found.map(
          (e) => _Step5ReviewLine(
            name: e.name,
            category: e.category,
          ),
        ),
      );
    _step5ReviewContinueEnabled = false;
  }

  ItemCategory _itemCategoryFromScanLabel(String raw) {
    final s = raw.toLowerCase().trim();
    switch (s) {
      case 'dairy':
        return ItemCategory.dairy;
      case 'produce':
        return ItemCategory.vegetables;
      case 'beverages':
        return ItemCategory.beverages;
      case 'condiments':
        return ItemCategory.condiments;
      case 'eggs':
        return ItemCategory.dairy;
      case 'bakery':
        return ItemCategory.bakery;
      case 'frozen':
        return ItemCategory.frozen;
      case 'snacks':
        return ItemCategory.pantry;
      case 'meat':
        return ItemCategory.meat;
      case 'seafood':
        return ItemCategory.meat;
      case 'prepared foods':
        return ItemCategory.pantry;
      case 'meals':
        return ItemCategory.pantry;
      default:
        return ItemCategory.other;
    }
  }

  void _commitScannedItemsToFridge() {
    final fridge = Provider.of<FridgeProvider>(context, listen: false);
    fridge.setConfiguredShelves(_sections);
    final shelf = _sections[
        (_addItemsZoneIndex ?? 0).clamp(0, _sections.length - 1)];
    for (final line in _step5ReviewLines) {
      final nameLower = line.name.toLowerCase().trim();
      if (nameLower.isEmpty) continue;
      if (fridge.items.any(
        (e) => !e.isConsumed && e.name.toLowerCase() == nameLower,
      )) {
        continue;
      }
      fridge.addItem(
        line.name,
        _itemCategoryFromScanLabel(line.category),
        DateTime.now().add(const Duration(days: 7)),
        quantity: '${line.qty}',
        shelf: shelf,
        imageUrl: ItemIllustration.urlFor(line.name, line.category),
      );
    }
  }

  Future<void> _openShelfScan() async {
    final zi = (_addItemsZoneIndex ?? 0).clamp(0, _sections.length - 1);
    final zone = _sections[zi];
    final raw = await Navigator.of(context).push<ShelfScanExit>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ShelfScanScreen(
          zoneLabel: zone,
          analysisService: _analysisService,
        ),
      ),
    );
    if (!mounted || raw == null || raw.items.isEmpty) return;
    setState(() {
      _mergeScannedItemsIntoShelf(raw.items);
      _shelfReviewImageBytes = raw.previewBytes;
      _applyScanToReviewLines(raw.items);
      _step5Ui = _Step5Ui.review;
    });
  }

  Future<void> _openShelfPhotoUpload() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    final zi = (_addItemsZoneIndex ?? 0).clamp(0, _sections.length - 1);
    final zone = _sections[zi];
    final raw = await Navigator.of(context).push<ShelfScanExit>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ShelfScanScreen(
          zoneLabel: zone,
          analysisService: _analysisService,
          initialGalleryBytes: bytes,
        ),
      ),
    );
    if (!mounted || raw == null || raw.items.isEmpty) return;
    setState(() {
      _mergeScannedItemsIntoShelf(raw.items);
      _shelfReviewImageBytes = raw.previewBytes ?? bytes;
      _applyScanToReviewLines(raw.items);
      _step5Ui = _Step5Ui.review;
    });
  }

  void _showStep5ChangeShelfSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'Choose shelf',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A2B4D),
                  ),
                ),
              ),
              for (int i = 0; i < _sections.length; i++)
                ListTile(
                  title: Text(_sections[i]),
                  trailing: (_addItemsZoneIndex ?? 0) == i
                      ? const Icon(Icons.check_circle, color: Color(0xFF2D7DFF))
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _addItemsZoneIndex = i);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openManualAddOnStep5() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Add item'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'Item name'),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final name = c.text.trim();
    c.dispose();
    if (ok != true || !mounted || name.isEmpty) return;
    setState(() {
      _shelfScannedItems.add(ShelfScanItem(name: name, category: 'Other'));
    });
  }

  String _step5ReviewCategorySummary() {
    final cats = _step5ReviewLines.map((e) => e.category).toSet().toList()
      ..sort();
    if (cats.isEmpty) return 'Groceries';
    return cats.take(5).join(' • ');
  }

  Widget _buildStepFive() {
    return _step5Ui == _Step5Ui.review
        ? _buildStepFiveReview()
        : _buildStepFiveHub();
  }

  Widget _buildStepFiveHub() {
    const primaryBlue = Color(0xFF2D7DFF);
    const purple = Color(0xFF7B68EE);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zi = (_addItemsZoneIndex ?? 0).clamp(0, _sections.length - 1);
    final zone = _sections[zi];
    final r = _analysisResult;
    final modelLine = '${r?.brand ?? ''} ${r?.model ?? ''}'.trim();
    final displayModel = modelLine.isEmpty ? 'Your fridge' : modelLine;

    Widget scanMethodCard({
      required Color bg,
      required Color accent,
      required IconData icon,
      required String badge,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 106),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainerHigh : bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? cs.outlineVariant.withOpacity(0.6)
                    : Colors.white.withOpacity(0.95),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark ? cs.surface : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: 19),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.48),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: accent,
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final extraScanned = _shelfScannedItems
        .where(
          (s) => !_step5QuickChips.any((q) => q.$2 == s.name),
        )
        .toList();

    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFFF4F7FC),
      child: LayoutBuilder(
        builder: (context, c) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: max(0.0, c.maxHeight - 14)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(
                        color: isDark ? cs.surfaceContainerHighest : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: primaryBlue.withOpacity(0.25),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 48,
                              height: 52,
                              child: _selectedImageBytes != null
                                  ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                                  : ColoredBox(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.kitchen_rounded, size: 24),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.view_stream_rounded,
                                      size: 16,
                                      color: primaryBlue.withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.55),
                                          ),
                                          children: [
                                            const TextSpan(text: 'Adding to: '),
                                            TextSpan(
                                              text: zone,
                                              style: TextStyle(
                                                color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayModel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 14,
                                      color: Colors.black.withOpacity(0.38),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Items added here will appear on your ${zone.toLowerCase()}.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          height: 1.25,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.45),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 0),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: _showStep5ChangeShelfSheet,
                                    child: const Text(
                                      'Change shelf ›',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'How would you like to add items?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 420;
                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              scanMethodCard(
                                bg: const Color(0xFFE8F4FF),
                                accent: primaryBlue,
                                icon: Icons.photo_camera_rounded,
                                badge: '✨ AI Powered',
                                title: 'Scan Items',
                                subtitle: 'Use camera to detect multiple items at once',
                                onTap: _openShelfScan,
                              ),
                              const SizedBox(height: 8),
                              scanMethodCard(
                                bg: const Color(0xFFF0EBFF),
                                accent: purple,
                                icon: Icons.photo_library_rounded,
                                badge: '✨ Quick & Easy',
                                title: 'Upload Photo',
                                subtitle: 'Upload a clear photo of your ${zone.toLowerCase()}',
                                onTap: _openShelfPhotoUpload,
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: scanMethodCard(
                                bg: const Color(0xFFE8F4FF),
                                accent: primaryBlue,
                                icon: Icons.photo_camera_rounded,
                                badge: '✨ AI Powered',
                                title: 'Scan Items',
                                subtitle: 'Use camera to detect multiple items at once',
                                onTap: _openShelfScan,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: scanMethodCard(
                                bg: const Color(0xFFF0EBFF),
                                accent: purple,
                                icon: Icons.photo_library_rounded,
                                badge: '✨ Quick & Easy',
                                title: 'Upload Photo',
                                subtitle: 'Upload a clear photo of your ${zone.toLowerCase()}',
                                onTap: _openShelfPhotoUpload,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: isDark ? cs.surfaceContainerHigh : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _openManualAddOnStep5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 20, color: Colors.black.withOpacity(0.55)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Add Manually',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                                      ),
                                    ),
                                    Text(
                                      'Search and add items yourself',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.45),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: Colors.black.withOpacity(0.35)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Common items on ${zone.toLowerCase()} ✨',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final q in _step5QuickChips)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                label: Text('${q.$1} ${q.$2}', style: const TextStyle(fontSize: 11)),
                                onPressed: () {
                                  setState(() {
                                    _shelfScannedItems.add(ShelfScanItem(name: q.$2, category: q.$3));
                                  });
                                },
                              ),
                            ),
                          for (final s in extraScanned)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                label: Text(s.name, style: const TextStyle(fontSize: 11)),
                                onPressed: () {
                                  setState(() {
                                    _step5ReviewLines
                                      ..clear()
                                      ..add(_Step5ReviewLine(name: s.name, category: s.category));
                                    _step5Ui = _Step5Ui.review;
                                    _step5ReviewContinueEnabled = false;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap any item above to add it quickly',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.42),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? cs.surfaceContainerHigh : const Color(0xFFE8F1FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('🐧', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tip: You can scan your shelf to add multiple items or add them manually one by one.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.52),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _nextStep,
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepFiveReview() {
    const primaryBlue = Color(0xFF2D7DFF);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zi = (_addItemsZoneIndex ?? 0).clamp(0, _sections.length - 1);
    final zone = _sections[zi];
    final imgBytes = _shelfReviewImageBytes ?? _selectedImageBytes;
    final n = _step5ReviewLines.length;
    final canContinue =
        _step5ReviewContinueEnabled && _step5ReviewLines.isNotEmpty;

    Future<void> addMissing() async {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add missing item'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'Item name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      final name = c.text.trim();
      c.dispose();
      if (ok != true || !mounted || name.isEmpty) return;
      setState(() {
        _step5ReviewLines
            .add(_Step5ReviewLine(name: name, category: 'Other'));
        _step5ReviewContinueEnabled = true;
      });
    }

    final narrowFooter = MediaQuery.sizeOf(context).width < 360;

    final Widget secondaryShelfBtn = OutlinedButton(
      onPressed: _showStep5ChangeShelfSheet,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            foregroundColor: isDark ? cs.onSurface : null,
            side: BorderSide(
              color: isDark
                  ? cs.outlineVariant.withOpacity(0.65)
                  : Colors.black.withOpacity(0.12),
            ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.kitchen_outlined,
              color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.55), size: 20),
          const SizedBox(height: 2),
          const Text(
            'Choose another shelf',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          Text(
            'Middle, door, etc.',
            style: TextStyle(
              fontSize: 9,
              color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );

    final Widget continueBtn = FilledButton(
      onPressed: canContinue
          ? () {
              _nextStep();
            }
          : null,
      style: FilledButton.styleFrom(
        backgroundColor: primaryBlue,
        disabledBackgroundColor: isDark ? cs.surfaceContainerHighest : Colors.grey.shade300,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Continue',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, size: 20),
        ],
      ),
    );

    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFFF4F7FC),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                  height: 1.15,
                ),
                children: [
                  const TextSpan(text: 'Friji scanned your '),
                  TextSpan(
                    text: '$zone!',
                    style: const TextStyle(color: Color(0xFF2D7DFF)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Review the items we found and confirm what\'s in your fridge.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.48),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imgBytes != null
                    ? Image.memory(
                        imgBytes,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      )
                    : ColoredBox(
                        color: Colors.grey.shade300,
                        child: Icon(Icons.kitchen_rounded,
                            size: 40, color: Colors.grey.shade500),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? cs.surfaceContainerHigh : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? cs.outlineVariant.withOpacity(0.55)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.kitchen_rounded,
                      color: primaryBlue.withOpacity(0.85), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          zone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                          ),
                        ),
                        Text(
                          _step5ReviewCategorySummary(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _showStep5ChangeShelfSheet,
                    child: const Text(
                      'Change shelf ›',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Items found ($n)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
              ),
            ),
            Text(
              'We found these items. Add, edit, or remove any that aren\'t correct.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              flex: 3,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: _step5ReviewLines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, i) => _buildStep5ReviewRow(i),
              ),
            ),
            const SizedBox(height: 4),
            Material(
              color: isDark ? cs.surfaceContainerHigh : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: addMissing,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isDark ? cs.surfaceContainer : const Color(0xFFE8F1FF),
                        child: Icon(Icons.add_rounded,
                            size: 20, color: primaryBlue),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Add missing items',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                              ),
                            ),
                            Text(
                              'Can\'t find something? Add it manually.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.black.withOpacity(0.35)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (narrowFooter)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  continueBtn,
                  const SizedBox(height: 8),
                  secondaryShelfBtn,
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: secondaryShelfBtn),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: continueBtn),
                ],
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildStep5ReviewRow(int i) {
    const primaryBlue = Color(0xFF2D7DFF);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line = _step5ReviewLines[i];
    return Material(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _step5ReviewContinueEnabled = true),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.network(
                      ItemIllustration.urlFor(line.name, line.category),
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: isDark ? cs.surfaceContainer : const Color(0xFFF4F7FC),
                        child: Center(
                          child: Text(
                            line.name.isNotEmpty
                                ? line.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF4A90E2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              line.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? cs.surfaceContainer : const Color(0xFFF0F2F7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                line.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.45),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? cs.surfaceContainer : const Color(0xFFE8F1FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      if (line.qty > 1) line.qty--;
                                      _step5ReviewContinueEnabled = true;
                                    });
                                  },
                                  icon: const Icon(Icons.remove, size: 16),
                                  color: primaryBlue,
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '${line.qty}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      line.qty++;
                                      _step5ReviewContinueEnabled = true;
                                    });
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  color: primaryBlue,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              final c =
                                  TextEditingController(text: line.name);
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Edit item'),
                                  content: TextField(
                                    controller: c,
                                    decoration: const InputDecoration(
                                        hintText: 'Name'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                              final t = c.text.trim();
                              c.dispose();
                              if (ok == true && t.isNotEmpty && mounted) {
                                setState(() {
                                  line.name = t;
                                  _step5ReviewContinueEnabled = true;
                                });
                              }
                            },
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            color: primaryBlue,
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() {
                                _step5ReviewLines.removeAt(i);
                                if (_step5ReviewLines.isEmpty) {
                                  _step5ReviewContinueEnabled = false;
                                }
                              });
                            },
                            icon: Icon(Icons.delete_outline,
                                size: 20, color: Colors.red.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildStepSix() {
    const primaryBlue = Color(0xFF2D7DFF);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zi = (_addItemsZoneIndex ?? 0).clamp(0, _sections.length - 1);
    final zone = _sections[zi];

    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFFF4F7FC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text(
              '🐧',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 12),
            Text(
              'All set!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isDark ? cs.onSurface : const Color(0xFF1A2B4D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your $zone is set up. You can add or edit items anytime from the home screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? cs.surfaceContainerHigh : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? cs.outlineVariant.withOpacity(0.55)
                      : Colors.black.withOpacity(0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration_outlined,
                      color: primaryBlue.withOpacity(0.9), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You finished steps 1–6. Tap below to save and start using Friji.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: isDark ? cs.onSurfaceVariant : Colors.black.withOpacity(0.52),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _recentItemTile(String name, String meta) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 52,
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.inventory_2_outlined,
                    size: 28, color: Color(0xFF4A90E2)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Color(0xFF1A2B4D),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            style: TextStyle(
              fontSize: 10,
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.check_circle, color: Color(0xFF34C759), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final isLast = _currentStep == 5;
    if (_currentStep == 2 ||
        _currentStep == 3 ||
        _currentStep == 4) {
      return const SizedBox.shrink();
    }
    if (_currentStep == 1 && _isAnalyzing) {
      return const SizedBox.shrink();
    }
    // First step + embedded camera: controls are inside the step (flash / capture / gallery).
    if (_currentStep == 0 && _setupMethod == 'Take a Photo') {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: (_currentStep == 1)
                  ? (_isAnalyzing || _selectedImageBytes == null
                      ? null
                      : () {
                          _startAnalyzing();
                        })
                  : (isLast
                      ? () {
                          _commitScannedItemsToFridge();
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop(true);
                          } else {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const NewUserDashboardScreen(
                                  initialNavigationIndex: 1,
                                ),
                              ),
                              (route) => false,
                            );
                          }
                        }
                        : () {
                          if (_currentStep == 0 &&
                              _selectedImageBytes == null &&
                              _setupMethod != 'Choose Manually') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please take or upload a fridge photo first.'),
                              ),
                            );
                            return;
                          }
                          _nextStep();
                        }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D7DFF),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                _currentStep == 1
                    ? (_isAnalyzing
                        ? 'Analyzing...'
                        : (_selectedImageBytes == null ? 'Start Detection' : 'Start Detection'))
                    : isLast
                        ? 'Save and Continue'
                        : 'Continue',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameSection(int index) async {
    final controller = TextEditingController(text: _sections[index]);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename section'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Section name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty) {
      setState(() => _sections[index] = updated);
    }
  }

  Widget _premiumCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _layoutTag(String title, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD3E3FF)),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4978BE),
          ),
        ),
      ),
    );
  }
}

class ConnectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90E2).withOpacity(0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw vertical line from top to bottom
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Draw small circle at bottom
    canvas.drawCircle(
      Offset(size.width / 2, size.height),
      3,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(ConnectorPainter oldDelegate) => false;
}

class _LayoutZoneSlot {
  const _LayoutZoneSlot({
    required this.sectionIndex,
    required this.alignment,
    required this.isDoor,
    required this.isFreezer,
    required this.paletteIndex,
  });

  final int sectionIndex;
  final Alignment alignment;
  final bool isDoor;
  final bool isFreezer;
  final int paletteIndex;
}

class ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final length = size.width * 0.1;
    final radius = 24.0;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(0, length)
        ..lineTo(0, radius)
        ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
        ..lineTo(length, 0),
      paint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - length, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius))
        ..lineTo(size.width, length),
      paint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - length)
        ..lineTo(0, size.height - radius)
        ..arcToPoint(Offset(radius, size.height), radius: Radius.circular(radius))
        ..lineTo(length, size.height),
      paint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - length)
        ..lineTo(size.width, size.height - radius)
        ..arcToPoint(Offset(size.width - radius, size.height),
            radius: Radius.circular(radius))
        ..lineTo(size.width - length, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnalyzingScanBandPainter extends CustomPainter {
  _AnalyzingScanBandPainter({required this.t, required this.strength});

  final double t;
  final double strength;

  static const _blue = Color(0xFF2D7DFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final y = size.height * (0.1 + t * 0.68);
    final bandH = size.height * 0.12;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, y),
      width: size.width * 1.08,
      height: bandH,
    );
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _blue.withOpacity(0.0),
          _blue.withOpacity(0.14 * strength),
          _blue.withOpacity(0.48 * strength),
          _blue.withOpacity(0.14 * strength),
          _blue.withOpacity(0.0),
        ],
        stops: const [0.0, 0.32, 0.5, 0.68, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, fill);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = _blue.withOpacity(0.32 * strength)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(rect.inflate(6), ring);
  }

  @override
  bool shouldRepaint(covariant _AnalyzingScanBandPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.strength != strength;
  }
}

class _AnalyzingBlueBracket extends StatelessWidget {
  const _AnalyzingBlueBracket({required this.quarterTurns});

  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF2D7DFF), width: 3),
            left: BorderSide(color: Color(0xFF2D7DFF), width: 3),
          ),
        ),
      ),
    );
  }
}

class _FridgeSetupLabeledStepper extends StatelessWidget {
  const _FridgeSetupLabeledStepper({required this.currentStep});

  final int currentStep;

  static const _labels = [
    'Upload Photo',
    'Detect Model',
    'Confirm Details',
    'Edit Layout',
    'Add Items',
    'All Set!',
  ];

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2D7DFF);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(6, (i) {
          final done = i < currentStep;
          final active = i == currentStep;
          final labelBlue =
              (i < 5 && i <= currentStep) || (i == 5 && currentStep == 5);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done || active ? accent : Colors.grey.shade300,
                  ),
                  alignment: Alignment.center,
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: active ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 76,
                  child: Text(
                    _labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: labelBlue ? accent : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _CameraCorner extends StatelessWidget {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final int rotateQuarterTurns;

  const _CameraCorner({
    this.left,
    this.right,
    this.top,
    this.bottom,
    this.rotateQuarterTurns = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: RotatedBox(
        quarterTurns: rotateQuarterTurns,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white, width: 3),
              left: BorderSide(color: Colors.white, width: 3),
            ),
          ),
        ),
      ),
    );
  }
}
