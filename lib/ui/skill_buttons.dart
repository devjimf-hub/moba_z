import 'dart:math';
import 'package:flutter/material.dart';

class SkillButtons extends StatelessWidget {
  final double skill1Cooldown;
  final double skill1MaxCooldown;
  final double skill2Cooldown;
  final double skill2MaxCooldown;
  final double ultimateCooldown;
  final double ultimateMaxCooldown;
  final VoidCallback? onSkill1Pressed;
  final VoidCallback? onSkill2Pressed;
  final VoidCallback? onUltimatePressed;
  final VoidCallback? onAttackPressed;

  const SkillButtons({
    super.key,
    required this.skill1Cooldown,
    required this.skill1MaxCooldown,
    required this.skill2Cooldown,
    required this.skill2MaxCooldown,
    required this.ultimateCooldown,
    required this.ultimateMaxCooldown,
    this.onSkill1Pressed,
    this.onSkill2Pressed,
    this.onUltimatePressed,
    this.onAttackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.of(context).size.height / 400).clamp(0.6, 1.5);
    return Positioned(
      bottom: 24,
      right: 24,
      child: SafeArea(
        child: SizedBox(
          width: 260 * scale,
          height: 260 * scale,
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                right: 150 * scale,
                child: _buildSkillButton(
                  label: 'Q',
                  icon: Icons.flash_on,
                  color: const Color(0xFF2196F3),
                  cooldown: skill1Cooldown,
                  maxCooldown: skill1MaxCooldown,
                  size: 56 * scale,
                  onPressed: onSkill1Pressed,
                ),
              ),
              Positioned(
                bottom: 90 * scale,
                right: 110 * scale,
                child: _buildSkillButton(
                  label: 'W',
                  icon: Icons.shield,
                  color: const Color(0xFF4CAF50),
                  cooldown: skill2Cooldown,
                  maxCooldown: skill2MaxCooldown,
                  size: 56 * scale,
                  onPressed: onSkill2Pressed,
                ),
              ),
              Positioned(
                bottom: 140 * scale,
                right: 20 * scale,
                child: _buildSkillButton(
                  label: 'R',
                  icon: Icons.local_fire_department,
                  color: const Color(0xFFFF9800),
                  cooldown: ultimateCooldown,
                  maxCooldown: ultimateMaxCooldown,
                  size: 64 * scale,
                  isUltimate: true,
                  onPressed: onUltimatePressed,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: _buildAttackButton(scale),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillButton({
    required String label,
    required IconData icon,
    required Color color,
    required double cooldown,
    required double maxCooldown,
    required double size,
    bool isUltimate = false,
    VoidCallback? onPressed,
  }) {
    final isOnCooldown = cooldown > 0;
    final cooldownPercent = maxCooldown > 0 ? (cooldown / maxCooldown).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: isOnCooldown ? null : onPressed,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha:  isOnCooldown ? 0.2 : 0.6),
                    color.withValues(alpha:  isOnCooldown ? 0.1 : 0.3),
                  ],
                ),
                border: Border.all(
                  color: color.withValues(alpha:  isOnCooldown ? 0.3 : 0.8),
                  width: 2,
                ),
                boxShadow: isOnCooldown
                    ? []
                    : [
                        BoxShadow(
                          color: color.withValues(alpha:  0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: isUltimate
                  ? CustomPaint(
                      painter: UltimateRingPainter(
                        color: color,
                        progress: isOnCooldown ? 0 : 1,
                      ),
                    )
                  : null,
            ),
            if (isOnCooldown)
              CustomPaint(
                size: Size(size, size),
                painter: CooldownPainter(
                  progress: cooldownPercent,
                  color: color,
                ),
              ),
            if (isOnCooldown)
              Text(
                cooldown.ceil().toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (!isOnCooldown)
              Icon(icon, color: Colors.white, size: size * 0.4),
            Positioned(
              bottom: -2,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha:  0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttackButton(double scale) {
    return GestureDetector(
      onTap: onAttackPressed,
      child: Container(
        width: 80 * scale,
        height: 80 * scale,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF44336), Color(0xFFC62828)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha:  0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF44336).withValues(alpha:  0.4),
              blurRadius: 12 * scale,
              spreadRadius: 2 * scale,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.gps_fixed,
            color: Colors.white,
            size: 40 * scale,
          ),
        ),
      ),
    );
  }
}

class CooldownPainter extends CustomPainter {
  final double progress;
  final Color color;

  CooldownPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha:  0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * pi * (1 - progress);
    final arcPaint = Paint()
      ..color = color.withValues(alpha:  0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CooldownPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class UltimateRingPainter extends CustomPainter {
  final Color color;
  final double progress;

  UltimateRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final ringPaint = Paint()
      ..color = color.withValues(alpha:  0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, ringPaint);

    if (progress > 0) {
      final activePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant UltimateRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
