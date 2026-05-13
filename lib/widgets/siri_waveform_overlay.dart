import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';

import 'package:flutter/material.dart';
import 'dart:math' as math;

class SiriWaveformOverlay extends StatefulWidget {
  final bool isListening;
  final bool isProcessing;
  final String? recognizedText;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const SiriWaveformOverlay({
    super.key,
    required this.isListening,
    this.isProcessing = false,
    this.recognizedText,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<SiriWaveformOverlay> createState() => _SiriWaveformOverlayState();
}

class _SiriWaveformOverlayState extends State<SiriWaveformOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.75), // Darker for better contrast
      child: Stack(
        children: [
          // Background Glow
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D7DFF).withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  
                  // Recognized Text Bubble
                  if (widget.recognizedText != null && widget.recognizedText!.isNotEmpty)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.recognizedText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  
                  // Animated Waveform
                  if (!widget.isProcessing)
                    SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: WavePainter(
                              animationValue: _waveController.value,
                              isListening: widget.isListening,
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 30),
                  
                  // Status Text
                  Text(
                    widget.isProcessing ? 'CONFIRM ACTION' : (widget.isListening ? 'LISTENING...' : 'THINKING...'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.0,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Action Buttons (Confirm/Cancel) - Below the text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Cancel Button (Red X)
                      _actionButton(
                        onTap: widget.onCancel,
                        icon: Icons.close_rounded,
                        color: Colors.red.withOpacity(0.2),
                        iconColor: Colors.redAccent,
                      ),
                      const SizedBox(width: 40),
                      // Main Icon (Mic or Loading)
                      Container(
                        height: 70,
                        width: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2D7DFF), Color(0xFF6366F1)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2D7DFF).withOpacity(0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Center(
                          child: widget.isProcessing 
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(Icons.mic_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                      const SizedBox(width: 40),
                      // Confirm Button (Green Check)
                      _actionButton(
                        onTap: widget.onConfirm,
                        icon: Icons.check_rounded,
                        color: const Color(0xFF00B894).withOpacity(0.2),
                        iconColor: const Color(0xFF00B894),
                      ),
                    ],
                  ),
                  
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    required Color iconColor,
    bool isSmall = false,
  }) {
    double size = 48; // Compact size for side buttons
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: iconColor.withOpacity(0.3), width: 1.5),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final bool isListening;

  WavePainter({required this.animationValue, required this.isListening});

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;
    final double width = size.width;

    void drawWave(Color color, double amplitude, double frequency, double phaseShift) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(0, midY);

      for (double x = 0; x <= width; x++) {
        // Apply a bell-curve mask to the amplitude so it fades at the edges
        double mask = math.exp(-math.pow((x - width / 2) / (width / 3), 2));
        double y = midY + amplitude * mask * math.sin(2 * math.pi * frequency * (x / width) + phaseShift + animationValue * 2 * math.pi);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    if (isListening) {
      drawWave(const Color(0xFF2D7DFF).withOpacity(0.8), 35, 1.5, 0);
      drawWave(const Color(0xFF6366F1).withOpacity(0.5), 25, 2.0, math.pi / 2);
      drawWave(const Color(0xFF8B5CF6).withOpacity(0.3), 15, 1.0, math.pi);
    } else {
      // Thinking: Faster, shallower waves
      drawWave(const Color(0xFF2D7DFF).withOpacity(0.6), 10, 3.0, animationValue * 4);
      drawWave(const Color(0xFF6366F1).withOpacity(0.4), 8, 4.0, animationValue * 4 + math.pi);
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isListening != isListening;
  }
}
