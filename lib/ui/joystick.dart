import 'dart:math';
import 'package:flutter/material.dart';

class VirtualJoystick extends StatefulWidget {
  final ValueChanged<Offset>? onJoystickMove;

  const VirtualJoystick({super.key, this.onJoystickMove});

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _stickPosition = Offset.zero;
  bool _isDragging = false;
  final double _baseRadius = 50;
  final double _stickRadius = 22;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 48,
      left: 48,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Container(
          width: _baseRadius * 2 + 20,
          height: _baseRadius * 2 + 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha:  0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha:  _isDragging ? 0.3 : 0.15),
              width: 2,
            ),
          ),
          child: CustomPaint(
            painter: JoystickPainter(
              stickPosition: _stickPosition,
              baseRadius: _baseRadius,
              stickRadius: _stickRadius,
              isDragging: _isDragging,
            ),
          ),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _updateStickPosition(details.localPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _updateStickPosition(details.localPosition);
    });
    _sendInput();
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _stickPosition = Offset.zero;
    });
    widget.onJoystickMove?.call(Offset.zero);
  }

  void _updateStickPosition(Offset localPosition) {
    final center = Offset(_baseRadius + 10, _baseRadius + 10);
    final delta = localPosition - center;
    final distance = delta.distance;
    final clampedDistance = min(distance, _baseRadius);
    if (distance > 0) {
      _stickPosition = Offset(
        (delta.dx / distance) * clampedDistance,
        (delta.dy / distance) * clampedDistance,
      );
    }
  }

  void _sendInput() {
    if (_baseRadius > 0) {
      final normalizedX = _stickPosition.dx / _baseRadius;
      final normalizedY = _stickPosition.dy / _baseRadius;
      widget.onJoystickMove?.call(Offset(normalizedX, normalizedY));
    }
  }
}

class JoystickPainter extends CustomPainter {
  final Offset stickPosition;
  final double baseRadius;
  final double stickRadius;
  final bool isDragging;

  JoystickPainter({
    required this.stickPosition,
    required this.baseRadius,
    required this.stickRadius,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final baseCirclePaint = Paint()
      ..color = Colors.white.withValues(alpha:  0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius, baseCirclePaint);

    final crosshairPaint = Paint()
      ..color = Colors.white.withValues(alpha:  0.08)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - baseRadius, center.dy),
      Offset(center.dx + baseRadius, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - baseRadius),
      Offset(center.dx, center.dy + baseRadius),
      crosshairPaint,
    );

    final directionPaint = Paint()
      ..color = Colors.white.withValues(alpha:  0.12)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi - pi / 2;
      final innerR = baseRadius - 12;
      final outerR = baseRadius - 4;
      canvas.drawLine(
        Offset(center.dx + cos(angle) * innerR, center.dy + sin(angle) * innerR),
        Offset(center.dx + cos(angle) * outerR, center.dy + sin(angle) * outerR),
        directionPaint,
      );
    }

    final stickCenter = center + stickPosition;
    final stickGlowPaint = Paint()
      ..color = const Color(0xFF2196F3).withValues(alpha:  isDragging ? 0.15 : 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(stickCenter, stickRadius + 8, stickGlowPaint);

    final stickPaint = Paint()
      ..color = isDragging ? const Color(0xFF2196F3).withValues(alpha:  0.8) : Colors.white.withValues(alpha:  0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(stickCenter, stickRadius, stickPaint);

    final stickBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha:  isDragging ? 0.6 : 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(stickCenter, stickRadius, stickBorderPaint);

    final dotPaint = Paint()..color = Colors.white.withValues(alpha:  isDragging ? 0.8 : 0.3);
    canvas.drawCircle(stickCenter, 4, dotPaint);

    if (stickPosition.distance > 10) {
      final dirPaint = Paint()
        ..color = Colors.white.withValues(alpha:  0.15)
        ..strokeWidth = 2;
      final dir = stickPosition / stickPosition.distance;
      final startPt = center + dir * (baseRadius + 5);
      final endPt = center + dir * (baseRadius + 15);
      canvas.drawLine(startPt, endPt, dirPaint);
    }
  }

  @override
  bool shouldRepaint(covariant JoystickPainter oldDelegate) {
    return oldDelegate.stickPosition != stickPosition ||
        oldDelegate.isDragging != isDragging;
  }
}
