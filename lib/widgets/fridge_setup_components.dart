import 'package:flutter/material.dart';

class ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLength = 40.0;
    const offset = 20.0;

    // Top-left
    canvas.drawLine(const Offset(offset, offset),
        const Offset(offset + cornerLength, offset), paint);
    canvas.drawLine(const Offset(offset, offset),
        const Offset(offset, offset + cornerLength), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - offset, offset),
        Offset(size.width - offset - cornerLength, offset), paint);
    canvas.drawLine(Offset(size.width - offset, offset),
        Offset(size.width - offset, offset + cornerLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(offset, size.height - offset),
        Offset(offset + cornerLength, size.height - offset), paint);
    canvas.drawLine(Offset(offset, size.height - offset),
        Offset(offset, size.height - offset - cornerLength), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - offset, size.height - offset),
        Offset(size.width - offset - cornerLength, size.height - offset), paint);
    canvas.drawLine(Offset(size.width - offset, size.height - offset),
        Offset(size.width - offset, size.height - offset - cornerLength), paint);
  }

  @override
  bool shouldRepaint(ViewfinderPainter oldDelegate) => false;
}

class SetupProgressHeader extends StatelessWidget {
  final int currentStep;

  const SetupProgressHeader({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${currentStep + 1} of 6',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A90E2),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / 6,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
            ),
          ),
        ],
      ),
    );
  }
}

class LabelBubble extends StatelessWidget {
  final String text;

  const LabelBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class TagDot extends StatelessWidget {
  final Alignment alignment;

  const TagDot({super.key, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFF4A90E2),
          borderRadius: BorderRadius.circular(7),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class CameraCorner extends StatelessWidget {
  final Alignment alignment;

  const CameraCorner({super.key, required this.alignment});

  @override
  Widget build(BuildContext context) {
    const cornerSize = 30.0;
    const thickness = 2.0;

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: cornerSize,
        height: cornerSize,
        child: CustomPaint(
          painter: CornerPainter(alignment),
        ),
      ),
    );
  }
}

class CornerPainter extends CustomPainter {
  final Alignment alignment;

  CornerPainter(this.alignment);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const len = 10.0;

    if (alignment == Alignment.topLeft) {
      canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
      canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    } else if (alignment == Alignment.topRight) {
      canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    } else if (alignment == Alignment.bottomLeft) {
      canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
      canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);
    } else if (alignment == Alignment.bottomRight) {
      canvas.drawLine(
          Offset(size.width, size.height), Offset(size.width - len, size.height), paint);
      canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), paint);
    }
  }

  @override
  bool shouldRepaint(CornerPainter oldDelegate) => false;
}
