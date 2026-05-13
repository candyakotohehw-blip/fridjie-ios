import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/fridge_analysis_service.dart';
import '../utils/item_illustration.dart';

/// One row returned from shelf item vision (Gemini).
class ShelfScanItem {
  ShelfScanItem({
    required this.name,
    required this.category,
  });

  final String name;
  final String category;
}

/// Result when the user finishes a shelf scan (live camera or gallery photo).
class ShelfScanExit {
  const ShelfScanExit({
    required this.items,
    this.previewBytes,
  });

  final List<ShelfScanItem> items;
  /// Photo that was scanned (gallery / re-pick). Null for live camera-only scan.
  final Uint8List? previewBytes;
}

/// Full-screen live camera or gallery photo UI for scanning a fridge zone (Step 5).
class ShelfScanScreen extends StatefulWidget {
  const ShelfScanScreen({
    super.key,
    required this.zoneLabel,
    required this.analysisService,
    this.initialGalleryBytes,
  });

  final String zoneLabel;
  final FridgeAnalysisService analysisService;

  /// When set, opens directly on this image (same scan UI + shutter as camera).
  final Uint8List? initialGalleryBytes;

  @override
  State<ShelfScanScreen> createState() => _ShelfScanScreenState();
}

class _ShelfScanScreenState extends State<ShelfScanScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  CameraController? _controller;
  bool _ready = false;
  bool _galleryMode = false;
  Uint8List? _galleryBytes;
  bool _flashOn = false;
  bool _finishing = false;
  int _foundCount = 0;
  final List<ShelfScanItem> _items = [];
  /// Decoded pixel size of gallery image (for true-aspect layout + scanner fit).
  Size? _galleryPixelSize;
  late final AnimationController _scanMotionController;

  Future<void> _loadGalleryPixelSize(Uint8List b) async {
    try {
      final codec = await ui.instantiateImageCodec(b);
      final frame = await codec.getNextFrame();
      final sz = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      if (mounted) setState(() => _galleryPixelSize = sz);
    } catch (_) {
      if (mounted) setState(() => _galleryPixelSize = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _scanMotionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    final initial = widget.initialGalleryBytes;
    if (initial != null && initial.isNotEmpty) {
      _galleryBytes = initial;
      _galleryMode = true;
      _ready = true;
      _loadGalleryPixelSize(initial);
    } else {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty || !mounted) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      await ctrl.setFlashMode(FlashMode.off);
      setState(() {
        _controller = ctrl;
        _ready = true;
      });
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _scanMotionController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  bool get _canScan => _galleryMode
      ? (_galleryBytes != null && _galleryBytes!.isNotEmpty)
      : (_controller != null && _ready);

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    final old = _controller;
    _controller = null;
    if (old != null) {
      try {
        await old.dispose();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _galleryBytes = bytes;
      _galleryMode = true;
      _ready = true;
      _flashOn = false;
      _finishing = false;
      _items.clear();
      _foundCount = 0;
      _galleryPixelSize = null;
    });
    _loadGalleryPixelSize(bytes);
  }

  Future<void> _toggleFlash() async {
    if (_galleryMode) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      final next = _flashOn ? FlashMode.off : FlashMode.torch;
      await c.setFlashMode(next);
      if (mounted) setState(() => _flashOn = !_flashOn);
    } catch (_) {}
  }

  String _mimeForBytes(Uint8List b) {
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'image/jpeg';
    }
    return 'image/jpeg';
  }

  Future<void> _runShelfAnalysis() async {
    if (!_canScan || _finishing) return;
    setState(() {
      _finishing = true;
      _items.clear();
      _foundCount = 0;
    });
    try {
      late final Uint8List rawBytes;
      if (_galleryMode && _galleryBytes != null) {
        rawBytes = _galleryBytes!;
      } else {
        final c = _controller;
        if (c == null || !c.value.isInitialized) {
          if (mounted) setState(() => _finishing = false);
          return;
        }
        final shot = await c.takePicture();
        rawBytes = await shot.readAsBytes();
      }

      const maxBytes = 4 * 1024 * 1024;
      if (rawBytes.length > maxBytes) {
        if (!mounted) return;
        setState(() => _finishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Masyadong malaki ang larawan. Pumili ng mas mababang resolution o i-crop muna.',
            ),
          ),
        );
        return;
      }

      final mime = _mimeForBytes(rawBytes);
      final b64 = base64Encode(rawBytes);
      final rows = await widget.analysisService.detectShelfItems(
        b64,
        mimeType: mime,
      );

      if (!mounted) return;
      final mapped = <ShelfScanItem>[];
      for (final r in rows) {
        final n = (r['name'] ?? '').toString().trim();
        final cat = (r['category'] ?? 'Other').toString().trim();
        if (n.length < 2) continue;
        mapped.add(
          ShelfScanItem(
            name: n,
            category: cat.isEmpty ? 'Other' : cat,
          ),
        );
      }

      setState(() {
        _items
          ..clear()
          ..addAll(mapped);
        _foundCount = _items.length;
        _finishing = false;
      });

      if (!mounted) return;
      if (mapped.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Walang item na natukoy nang malinaw sa larawan. Subukan ang mas maliwanag na kuha o mas malapit na anggulo.',
            ),
          ),
        );
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      Navigator.pop(
        context,
        ShelfScanExit(
          items: List<ShelfScanItem>.from(_items),
          previewBytes: _galleryBytes,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      final errorText = e.toString().toLowerCase();
      final isRateLimited =
          errorText.contains('rate limit') || errorText.contains('429');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRateLimited
                ? 'Masyadong maraming requests sa ngayon. Maghintay ng ilang segundo, tapos scan ulit.'
                : 'Hindi ma-scan ang items: $e',
          ),
          backgroundColor:
              isRateLimited ? Colors.orange.shade800 : Colors.red.shade800,
        ),
      );
    }
  }

  String _initials(ShelfScanItem it) {
    final p = it.name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final list = p.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) {
      final s = list[0];
      return s.length >= 2
          ? '${s[0]}${s[1]}'.toUpperCase()
          : s[0].toUpperCase();
    }
    return '${list[0][0]}${list[1][0]}'.toUpperCase();
  }

  Widget _itemThumb(ShelfScanItem it) {
    const frijiBlue = Color(0xFF2D7DFF);
    final url = ItemIllustration.urlFor(it.name, it.category);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.22),
                        Colors.white.withOpacity(0.08),
                      ],
                    ),
                    border: Border.all(color: Colors.white30, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: frijiBlue.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Text(
                      _initials(it),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF1A2B4D),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.check_rounded,
                        color: frijiBlue,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              it.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Upload photo: true image aspect + blue frame hugging the photo.
  Widget _galleryImageWithFrame({
    required Color frijiBlue,
    required double maxW,
    required double maxH,
  }) {
    final pixel = _galleryPixelSize!;
    final bytes = _galleryBytes!;
    final iw = pixel.width;
    final ih = pixel.height;
    var dw = maxW;
    var dh = dw * ih / iw;
    if (dh > maxH) {
      dh = maxH;
      dw = dh * iw / ih;
    }
    return SizedBox(
      width: dw,
      height: dh,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: dw,
              height: dh,
              gaplessPlayback: true,
            ),
          ),
          CustomPaint(
            painter: _ShelfScanFramePainter(
              color: frijiBlue,
              borderRadius: 10,
            ),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const frijiBlue = Color(0xFF2D7DFF);
    final zone = widget.zoneLabel;
    final compactControls = MediaQuery.sizeOf(context).height < 760;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_galleryMode && _galleryBytes != null)
            Positioned.fill(
              child: ColoredBox(color: Colors.black),
            )
          else if (_controller != null && _ready)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final ctrl = _controller!;
                    final sz = ctrl.value.previewSize;
                    if (sz == null) return CameraPreview(ctrl);
                    return FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: sz.height.toDouble(),
                        height: sz.width.toDouble(),
                        child: CameraPreview(ctrl),
                      ),
                    );
                  },
                ),
              ),
            )
          else if (!_galleryMode)
            const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            )
          else
            const SizedBox.shrink(),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.78),
                    Colors.black.withOpacity(0.18),
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.88),
                  ],
                  stops: const [0.0, 0.12, 0.42, 0.72, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.88),
                        Colors.black.withOpacity(0.35),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 28),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                _galleryMode
                                    ? 'Scanning ${zone.toLowerCase()}…'
                                    : 'Scanning $zone…',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _galleryMode
                                    ? 'Friji is reading items from your uploaded photo'
                                    : 'Friji is looking for items on the ${zone.toLowerCase()}',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.88),
                                  fontSize: 11,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _galleryMode ? null : _toggleFlash,
                          icon: Icon(
                            _flashOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: _galleryMode
                                ? Colors.white24
                                : Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.maxWidth;
                      final maxH = constraints.maxHeight;

                      Widget topBanner() {
                        return Positioned(
                          top: 4,
                          left: 10,
                          right: 10,
                          child: Material(
                            color: Colors.white,
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.kitchen_outlined,
                                      color: frijiBlue, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _galleryMode
                                              ? '$zone (photo)'
                                              : '$zone detected',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: Color(0xFF1A2B4D),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _galleryMode
                                              ? 'Whole photo in frame — tap shutter when ready.'
                                              : 'Keep the shelf inside the frame.',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            height: 1.2,
                                            color: Colors.black
                                                .withOpacity(0.52),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF34C759), size: 22),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      Widget bottomHint() {
                        return Positioned(
                          bottom: 8,
                          left: 16,
                          right: 16,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Text(
                                _galleryMode
                                    ? 'Tap shutter — we\'ll detect items from this photo'
                                    : 'Make sure items are clearly visible',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 11.5,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      if (_galleryMode &&
                          _galleryBytes != null &&
                          _galleryPixelSize != null) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: _galleryImageWithFrame(
                                frijiBlue: frijiBlue,
                                maxW: maxW - 8,
                                maxH: maxH - 10,
                              ),
                            ),
                            topBanner(),
                            bottomHint(),
                          ],
                        );
                      }

                      if (_galleryMode && _galleryBytes != null) {
                        return Stack(
                          children: [
                            const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                            topBanner(),
                            bottomHint(),
                          ],
                        );
                      }

                      var frameW = (maxW * 0.78).clamp(190.0, maxW - 20);
                      var frameH = frameW * 0.58;
                      if (frameH > maxH * 0.58) {
                        frameH = maxH * 0.58;
                        frameW = frameH / 0.58;
                      }

                      return Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          topBanner(),
                          AnimatedBuilder(
                            animation: _scanMotionController,
                            builder: (_, __) {
                              final t = _scanMotionController.value * math.pi * 2;
                              final x = math.sin(t) * 0.16;
                              final y = math.sin(t * 0.7) * 0.05;
                              final scale = 0.96 + (math.cos(t) * 0.04);
                              return Align(
                                alignment: Alignment(x, y),
                                child: Transform.scale(
                                  scale: scale,
                                  child: CustomPaint(
                                    painter: _ShelfScanFramePainter(
                                      color: frijiBlue,
                                      borderRadius: 14,
                                    ),
                                    child: SizedBox(
                                      width: frameW,
                                      height: frameH,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          bottomHint(),
                        ],
                      );
                    },
                  ),
                ),
                Material(
                  color: Colors.black.withOpacity(0.58),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          compactControls ? 4 : 6,
                          12,
                          compactControls ? 0 : 2,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: _finishing
                                      ? const Padding(
                                          padding: EdgeInsets.all(2),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: frijiBlue,
                                          ),
                                        )
                                      : Icon(
                                          Icons.search_rounded,
                                          color: frijiBlue.withOpacity(0.95),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Found $_foundCount items so far',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                      Text(
                                        _galleryMode
                                            ? 'We\'ll use this photo to list items after you tap shutter.'
                                            : "We'll show results after you finish scanning.",
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.75),
                                          fontSize: 11.5,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compactControls ? 4 : 6),
                            SizedBox(
                              height: compactControls ? 56 : 68,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.zero,
                                children: [
                                  for (final it in _items) _itemThumb(it),
                                  if (_foundCount > 5)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border:
                                              Border.all(color: Colors.white24),
                                        ),
                                        child: Text(
                                          '+${_foundCount - 5}\nmore',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: frijiBlue,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: compactControls ? 2 : 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _runShelfAnalysis,
                                  child: Container(
                                    width: compactControls ? 58 : 68,
                                    height: compactControls ? 58 : 68,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: frijiBlue,
                                        width: 3.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: frijiBlue.withOpacity(0.45),
                                          blurRadius: 14,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _pickFromGallery,
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Glowing rounded frame with L-bracket corners (scanner overlay).
class _ShelfScanFramePainter extends CustomPainter {
  _ShelfScanFramePainter({
    required this.color,
    required this.borderRadius,
  });

  final Color color;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    final glow = Paint()
      ..color = color.withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(r, glow);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;
    canvas.drawRRect(r, stroke);

    const len = 18.0;
    const th = 2.8;
    final corner = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = th
      ..strokeCap = StrokeCap.round;

    final inset = th / 2;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(
      Offset(inset, inset),
      Offset(inset, inset + len),
      corner,
    );
    canvas.drawLine(
      Offset(inset, inset),
      Offset(inset + len, inset),
      corner,
    );
    // Top-right
    canvas.drawLine(
      Offset(w - inset, inset),
      Offset(w - inset, inset + len),
      corner,
    );
    canvas.drawLine(
      Offset(w - inset, inset),
      Offset(w - inset - len, inset),
      corner,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(inset, h - inset),
      Offset(inset, h - inset - len),
      corner,
    );
    canvas.drawLine(
      Offset(inset, h - inset),
      Offset(inset + len, h - inset),
      corner,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(w - inset, h - inset),
      Offset(w - inset, h - inset - len),
      corner,
    );
    canvas.drawLine(
      Offset(w - inset, h - inset),
      Offset(w - inset - len, h - inset),
      corner,
    );
  }

  @override
  bool shouldRepaint(covariant _ShelfScanFramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}
