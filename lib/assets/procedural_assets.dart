import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../utils/constants.dart';

class ProceduralAssets {
  ProceduralAssets._();

  static ui.Image? minionImage;
  static ui.Image? turretImage;
  static ui.Image? warriorUp;
  static ui.Image? warriorDown;
  static ui.Image? warriorSide;
  static ui.Image? warriorPreHit;
  static ui.Image? warriorPostHit;

  static Future<ui.Image?> _loadImage(String path) async {
    try {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      return frameInfo.image;
    } catch (e) {
      debugPrint('Failed to load image $path: $e');
      return null;
    }
  }

  static Future<void> loadAssets() async {
    minionImage = await _loadImage('assets/images/minion_sprite.png');
    turretImage = await _loadImage('assets/images/turret_sprite.png');
    warriorUp = await _loadImage('assets/images/warior/up.png');
    warriorDown = await _loadImage('assets/images/warior/down.png');
    warriorSide = await _loadImage('assets/images/warior/side.png');
    warriorPreHit = await _loadImage('assets/images/warior/pre_hit.png');
    warriorPostHit = await _loadImage('assets/images/warior/post_hit.png');
  }

  static void drawHero(Canvas canvas, String heroKey, Vector2 position, double angle, double animTime, bool isAlive, Team team, {bool isMoving = false, bool isAttacking = false, bool isMirrored = false}) {
    if (!isAlive) return;
    final colors = team == Team.blue ? _blueHeroColors[heroKey] : _redHeroColors[heroKey];
    final bodyColor = colors?['body'] ?? Colors.white;
    final accentColor = colors?['accent'] ?? Colors.grey;
    final size = 20.0;
    
    double dashX = 0;
    double dashY = 0;
    if (isAttacking) {
      final progress = (animTime * 3.0) % 1.0;
      final dashDist = (progress < 0.2 ? progress / 0.2 : (1.0 - progress) / 0.8) * 15.0;
      dashX = cos(angle) * dashDist;
      dashY = sin(angle) * dashDist;
    }

    final bobOffset = isMoving ? sin(animTime * 8.0) * 3.0 : 0.0;

    canvas.save();
    canvas.translate(position.x + dashX, position.y + dashY + bobOffset);
    if (isMirrored) canvas.rotate(pi);
    canvas.scale(3.0, 3.0);
    
    double screenAngle = isMirrored ? angle + pi : angle;
    
    if (isMoving) {
      final s = sin(animTime * 8.0);
      canvas.scale(1.0 - 0.1 * s, 1.0 + 0.1 * s);
      canvas.rotate(s * 0.087);
    }
    
    if (heroKey == 'warrior' && warriorSide != null) {
      final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.25);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 10), width: 16, height: 6),
        shadowPaint,
      );

      ui.Image? currentImg;
      bool flipHorizontal = false;

      if (isAttacking) {
        final progress = (animTime * 3.0) % 1.0;
        currentImg = progress < 0.2 ? warriorPreHit : warriorPostHit;
        if (cos(screenAngle) < 0) flipHorizontal = true;
      } else {
        final pi4 = pi / 4;
        double normAngle = screenAngle % (2 * pi);
        if (normAngle > pi) normAngle -= 2 * pi;
        if (normAngle < -pi) normAngle += 2 * pi;

        if (normAngle > -pi4 && normAngle <= pi4) {
          currentImg = warriorSide;
        } else if (normAngle > pi4 && normAngle <= 3 * pi4) {
          currentImg = warriorDown;
        } else if (normAngle < -pi4 && normAngle >= -3 * pi4) {
          currentImg = warriorUp;
        } else {
          currentImg = warriorSide;
          flipHorizontal = true;
        }
      }

      if (currentImg != null) {
        if (flipHorizontal) canvas.scale(-1.0, 1.0);
        
        if (isMoving && !isAttacking) {
          final matrix = Matrix4.identity();
          matrix.setEntry(0, 1, -0.2);
          canvas.transform(matrix.storage);
        }

        final imgWidth = 48.0;
        final imgHeight = 48.0;
        final imgRect = Rect.fromCenter(center: const Offset(0, -12), width: imgWidth, height: imgHeight);
        final srcRect = Rect.fromLTWH(0, 0, currentImg.width.toDouble(), currentImg.height.toDouble());
        
        final glowPaint = Paint()
          ..colorFilter = ColorFilter.mode(team == Team.blue ? TeamColors.blueTeam : TeamColors.redTeam, BlendMode.srcIn)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawImageRect(currentImg, srcRect, imgRect, glowPaint);
        
        canvas.drawImageRect(currentImg, srcRect, imgRect, Paint());
        canvas.restore();
        return;
      }
    }

    canvas.rotate(screenAngle);
    
    if (isMoving) {
      final matrix = Matrix4.identity();
      matrix.setEntry(0, 1, -0.2);
      canvas.transform(matrix.storage);
    }
    
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha:  0.3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, size * 0.6), width: size * 1.4, height: size * 0.5),
      shadowPaint,
    );
    final bodyPaint = Paint()..color = bodyColor;
    canvas.drawCircle(Offset.zero, size, bodyPaint);
    final accentPaint = Paint()..color = accentColor;
    canvas.drawCircle(Offset(0, -size * 0.3), size * 0.6, accentPaint);
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size * 0.3, -size * 0.1), 4.0, eyePaint);
    canvas.drawCircle(Offset(-size * 0.3, -size * 0.1), 4.0, eyePaint);
    final pupilPaint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(size * 0.3 + cos(screenAngle) * 1.5, -size * 0.1 + sin(screenAngle) * 1.5), 2.0, pupilPaint);
    canvas.drawCircle(Offset(-size * 0.3 + cos(screenAngle) * 1.5, -size * 0.1 + sin(screenAngle) * 1.5), 2.0, pupilPaint);
    final outlinePaint = Paint()
      ..color = team == Team.blue ? TeamColors.blueTeamDark : TeamColors.redTeamDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset.zero, size, outlinePaint);
    canvas.restore();
  }

  static void drawMinion(Canvas canvas, MinionType type, Vector2 position, double angle, Team team, bool isAlive, double animTime, {bool isMoving = false, bool isAttacking = false, bool isMirrored = false}) {
    if (!isAlive) return;
    
    double dashX = 0;
    double dashY = 0;
    if (isAttacking) {
      final progress = (animTime * 3.0) % 1.0;
      final dashDist = (progress < 0.2 ? progress / 0.2 : (1.0 - progress) / 0.8) * 15.0;
      dashX = cos(angle) * dashDist;
      dashY = sin(angle) * dashDist;
    }

    final bobSpeed = isAttacking ? 20.0 : (isMoving ? 8.0 : 4.0);
    final bobAmp = isAttacking ? 12.0 : (isMoving ? 9.0 : 4.5);
    final bobOffset = sin(animTime * bobSpeed) * bobAmp;
    
    canvas.save();
    canvas.translate(position.x + dashX, position.y + dashY + bobOffset);
    if (isMirrored) canvas.rotate(pi);
    canvas.scale(3.0, 3.0);
    
    double screenAngle = isMirrored ? angle + pi : angle;
    
    if (isMoving) {
      final s = sin(animTime * 8.0);
      canvas.scale(1.0 - 0.1 * s, 1.0 + 0.1 * s);
      canvas.rotate(s * 0.087);
    }

    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 10), width: 16, height: 6),
      shadowPaint,
    );

    if (minionImage != null) {
      if (cos(screenAngle) < 0) {
        canvas.scale(-1, 1);
      }
      
      if (isMoving) {
        final matrix = Matrix4.identity();
        matrix.setEntry(0, 1, -0.2);
        canvas.transform(matrix.storage);
      }
      
      final imgWidth = 36.0;
      final imgHeight = 36.0;
      final imgRect = Rect.fromCenter(center: const Offset(0, -8), width: imgWidth, height: imgHeight);
      final srcRect = Rect.fromLTWH(0, 0, minionImage!.width.toDouble(), minionImage!.height.toDouble());
      
      // Draw sprite-shaped glow behind the actual image (2x stronger)
      final glowPaint = Paint()
        ..colorFilter = ColorFilter.mode(team == Team.blue ? TeamColors.blueTeam : TeamColors.redTeam, BlendMode.srcIn)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawImageRect(minionImage!, srcRect, imgRect, glowPaint);
      canvas.drawImageRect(minionImage!, srcRect, imgRect, glowPaint);

      canvas.drawImageRect(
        minionImage!,
        srcRect,
        imgRect,
        Paint(),
      );
    } else {
      canvas.rotate(screenAngle);
      if (isMoving) {
        final matrix = Matrix4.identity();
        matrix.setEntry(0, 1, -0.2);
        canvas.transform(matrix.storage);
      }
      final teamColor = team == Team.blue ? TeamColors.blueTeam : TeamColors.redTeam;
      switch (type) {
        case MinionType.melee:
          final bodyPaint = Paint()..color = teamColor;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 20, height: 20), const Radius.circular(4)),
            bodyPaint,
          );
          final weaponPaint = Paint()..color = TeamColors.stoneGray;
          canvas.drawRect(Rect.fromCenter(center: const Offset(14, 0), width: 10, height: 4), weaponPaint);
          break;
        case MinionType.ranged:
          final bodyPaint = Paint()..color = teamColor.withValues(alpha: 0.8);
          canvas.drawCircle(Offset.zero, 9, bodyPaint);
          final staffPaint = Paint()..color = TeamColors.gold;
          canvas.drawRect(Rect.fromCenter(center: const Offset(12, -4), width: 3, height: 16), staffPaint);
          final orbPaint = Paint()..color = Colors.cyan;
          canvas.drawCircle(const Offset(12, -12), 4, orbPaint);
          break;
        case MinionType.siege:
          final bodyPaint = Paint()..color = teamColor.withValues(alpha: 0.9);
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 28, height: 22), const Radius.circular(6)),
            bodyPaint,
          );
          final turretPaint = Paint()..color = TeamColors.stoneGray;
          canvas.drawRect(Rect.fromCenter(center: const Offset(0, -12), width: 8, height: 10), turretPaint);
          final wheelPaint = Paint()..color = TeamColors.groundBrown;
          canvas.drawCircle(const Offset(-10, 10), 5, wheelPaint);
          canvas.drawCircle(const Offset(10, 10), 5, wheelPaint);
          break;
      }
      final glowPaint = Paint()
        ..color = (team == Team.blue ? TeamColors.blueTeam : TeamColors.redTeam).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset.zero, type == MinionType.siege ? 16 : 12, glowPaint);
    }
    
    canvas.restore();
  }

  static void drawTurret(Canvas canvas, Vector2 position, Team team, StructureType type, bool isAlive, double animTime, {bool isMirrored = false}) {
    if (!isAlive) return;

    if (turretImage != null) {
      final pulse = sin(animTime * 2.0) * 0.05 + 1.0;
      canvas.save();
      canvas.translate(position.x, position.y);
      if (isMirrored) canvas.rotate(pi);
      canvas.scale(3.0 * pulse, 3.0 * pulse);
      
      final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 15), width: 32, height: 12),
        shadowPaint,
      );

      final imgWidth = 48.0;
      final imgHeight = 64.0;
      
      final imgRect = Rect.fromCenter(center: const Offset(0, -16), width: imgWidth, height: imgHeight);
      final srcRect = Rect.fromLTWH(0, 0, turretImage!.width.toDouble(), turretImage!.height.toDouble());

      // Draw sprite-shaped glow behind the actual image (2x stronger)
      final glowPaint = Paint()
        ..colorFilter = ColorFilter.mode(team == Team.blue ? TeamColors.blueTeam : TeamColors.redTeam, BlendMode.srcIn)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      canvas.drawImageRect(turretImage!, srcRect, imgRect, glowPaint);
      canvas.drawImageRect(turretImage!, srcRect, imgRect, glowPaint);
      
      // If red team, flip it? Maybe tint it!
      final paint = Paint();
      if (team == Team.red) {
        paint.colorFilter = const ColorFilter.mode(Color(0xFFFFCCCC), BlendMode.modulate);
      } else {
        paint.colorFilter = const ColorFilter.mode(Color(0xFFCCCCFF), BlendMode.modulate);
      }

      canvas.drawImageRect(
        turretImage!,
        srcRect,
        imgRect,
        paint,
      );
      
      canvas.restore();
      return;
    }

    final teamColor = team == Team.blue ? TeamColors.blueTeamDark : TeamColors.redTeamDark;
    final teamLight = team == Team.blue ? TeamColors.blueTeamLight : TeamColors.redTeamLight;
    final size = type == StructureType.baseTurret ? 28.0 : type == StructureType.innerTurret ? 24.0 : 20.0;
    final pulse = sin(animTime * 2.0) * 0.1 + 0.9;
    canvas.save();
    canvas.translate(position.x, position.y);
    if (isMirrored) canvas.rotate(pi);
    canvas.scale(3.0, 3.0);
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha:  0.4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, size * 0.5), width: size * 2, height: size * 0.8),
      shadowPaint,
    );
    final basePaint = Paint()..color = TeamColors.stoneGray;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, size * 0.3), width: size * 1.8, height: size * 0.8),
        Radius.circular(4),
      ),
      basePaint,
    );
    final towerPaint = Paint()..color = teamColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -size * 0.2), width: size * 1.2, height: size * 1.6),
        Radius.circular(6),
      ),
      towerPaint,
    );
    final topPaint = Paint()..color = teamLight;
    canvas.drawCircle(Offset(0, -size * 0.7), size * 0.5, topPaint);
    final glowPaint = Paint()
      ..color = teamColor.withValues(alpha:  pulse * 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(0, -size * 0.7), size * 0.6, glowPaint);
    final gemPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(0, -size * 0.7), size * 0.15, gemPaint);
    canvas.restore();
  }

  static void drawCrystal(Canvas canvas, Vector2 position, Team team, bool isAlive, double hpPercent, double animTime, {bool isMirrored = false}) {
    if (!isAlive) return;
    final teamColor = team == Team.blue ? TeamColors.blueTeam : TeamColors.redTeam;
    final teamLight = team == Team.blue ? TeamColors.blueTeamLight : TeamColors.redTeamLight;
    final pulse = sin(animTime * 1.5) * 0.15 + 0.85;
    canvas.save();
    canvas.translate(position.x, position.y);
    if (isMirrored) canvas.rotate(pi);
    canvas.scale(3.0, 3.0);
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha:  0.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 25), width: 60, height: 20),
      shadowPaint,
    );
    final basePaint = Paint()..color = TeamColors.stoneGray;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, 15), width: 50, height: 20), Radius.circular(4)),
      basePaint,
    );
    final path = Path();
    path.moveTo(0, -35);
    path.lineTo(20, -5);
    path.lineTo(15, 15);
    path.lineTo(-15, 15);
    path.lineTo(-20, -5);
    path.close();
    final crystalPaint = Paint()..color = teamColor.withValues(alpha:  0.9);
    canvas.drawPath(path, crystalPaint);
    final innerPath = Path();
    innerPath.moveTo(0, -25);
    innerPath.lineTo(10, -5);
    innerPath.lineTo(5, 10);
    innerPath.lineTo(-5, 10);
    innerPath.lineTo(-10, -5);
    innerPath.close();
    final innerPaint = Paint()..color = teamLight.withValues(alpha:  0.6);
    canvas.drawPath(innerPath, innerPaint);
    final glowPaint = Paint()
      ..color = teamColor.withValues(alpha:  pulse * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(Offset(0, -10), 30 * pulse, glowPaint);
    final crackPaint = Paint()
      ..color = Colors.white.withValues(alpha:  0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(-5, -20), Offset(3, -5), crackPaint);
    canvas.drawLine(Offset(3, -5), Offset(-2, 5), crackPaint);
    canvas.restore();
  }

  static void drawProjectile(Canvas canvas, Vector2 position, double angle, ProjectileType type, Team team, {bool isMirrored = false}) {
    canvas.save();
    canvas.translate(position.x, position.y);
    if (isMirrored) canvas.rotate(pi);
    canvas.scale(3.0, 3.0);
    double screenAngle = isMirrored ? angle + pi : angle;
    canvas.rotate(screenAngle);
    final teamColor = team == Team.blue ? TeamColors.blueTeamLight : TeamColors.redTeamLight;
    switch (type) {
      case ProjectileType.basicAttack:
        final paint = Paint()..color = teamColor;
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 6), paint);
        final glowPaint = Paint()
          ..color = teamColor.withValues(alpha:  0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 16, height: 10), glowPaint);
        break;
      case ProjectileType.skill:
        final paint = Paint()..color = Colors.cyan;
        canvas.drawCircle(Offset.zero, 8, paint);
        final innerPaint = Paint()..color = Colors.white;
        canvas.drawCircle(Offset.zero, 4, innerPaint);
        final outerGlow = Paint()
          ..color = Colors.cyan.withValues(alpha:  0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset.zero, 14, outerGlow);
        break;
      case ProjectileType.turret:
        final paint = Paint()..color = teamColor;
        canvas.drawCircle(Offset.zero, 6, paint);
        final trailPaint = Paint()
          ..color = teamColor.withValues(alpha:  0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(-8, 0), 5, trailPaint);
        break;
      case ProjectileType.minion:
        final paint = Paint()..color = teamColor;
        canvas.drawCircle(Offset.zero, 4, paint);
        break;
    }
    canvas.restore();
  }

  static void drawTree(Canvas canvas, Vector2 position, double animTime) {
    canvas.save();
    canvas.translate(position.x, position.y);
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha:  0.25);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(4, 18), width: 24, height: 12),
      shadowPaint,
    );
    final trunkPaint = Paint()..color = TeamColors.treeBrown;
    canvas.drawRect(Rect.fromCenter(center: Offset(0, 6), width: 8, height: 20), trunkPaint);
    final sway = sin(animTime * 0.8 + position.x * 0.01) * 2;
    final foliagePaint = Paint()..color = TeamColors.treeGreen;
    canvas.drawCircle(Offset(sway, -12), 18, foliagePaint);
    final foliageDarkPaint = Paint()..color = TeamColors.treeDarkGreen;
    canvas.drawCircle(Offset(sway - 6, -8), 12, foliageDarkPaint);
    final foliageLightPaint = Paint()..color = TeamColors.grassLightGreen;
    canvas.drawCircle(Offset(sway + 8, -16), 8, foliageLightPaint);
    canvas.restore();
  }

  static void drawBush(Canvas canvas, Vector2 position, double radius, double animTime) {
    canvas.save();
    canvas.translate(position.x, position.y);
    final sway = sin(animTime * 1.5 + position.x * 0.02) * 3;
    final bushPaint = Paint()..color = TeamColors.grassGreen.withValues(alpha:  0.85);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(sway, 0), width: radius * 2.2, height: radius * 1.4),
      bushPaint,
    );
    final bushLightPaint = Paint()..color = TeamColors.grassLightGreen.withValues(alpha:  0.7);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(sway + 5, -3), width: radius * 1.4, height: radius * 0.8),
      bushLightPaint,
    );
    for (int i = 0; i < 5; i++) {
      final angle = (i / 5) * pi * 2 + animTime * 0.3;
      final bladeX = cos(angle) * radius * 0.8 + sway;
      final bladeY = sin(angle) * radius * 0.5 - 5;
      final bladePaint = Paint()..color = TeamColors.grassGreen;
      canvas.drawLine(
        Offset(bladeX, bladeY + 8),
        Offset(bladeX + sin(animTime + i) * 3, bladeY - 6),
        bladePaint..strokeWidth = 2,
      );
    }
    canvas.restore();
  }

  static void drawGrassPatch(Canvas canvas, double x, double y, double w, double h, double animTime) {
    for (double gx = x; gx < x + w; gx += 8) {
      for (double gy = y; gy < y + h; gy += 8) {
        final sway = sin(animTime * 2.0 + gx * 0.05 + gy * 0.03) * 2;
        final hue = (sin(gx * 0.02 + gy * 0.01) * 0.5 + 0.5);
        final green = (100 + hue * 80).toInt();
        final bladePaint = Paint()..color = Color.fromARGB(200, 40, green, 30);
        canvas.drawLine(
          Offset(gx, gy + 6),
          Offset(gx + sway, gy - 4),
          bladePaint..strokeWidth = 1.5,
        );
      }
    }
  }

  static void drawStonePath(Canvas canvas, double x, double y, double w, double h) {
    final pathPaint = Paint()..color = TeamColors.stoneGray;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), pathPaint);
    final rng = Random(x.toInt() * 1000 + y.toInt());
    for (int i = 0; i < (w * h / 400).toInt(); i++) {
      final sx = x + rng.nextDouble() * w;
      final sy = y + rng.nextDouble() * h;
      final sw = 12.0 + rng.nextDouble() * 20;
      final sh = 10.0 + rng.nextDouble() * 16;
      final stonePaint = Paint()..color = TeamColors.stoneLightGray.withValues(alpha:  0.6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(sx, sy, sw, sh), Radius.circular(3)),
        stonePaint,
      );
      final edgePaint = Paint()
        ..color = TeamColors.stoneGray
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(sx, sy, sw, sh), Radius.circular(3)),
        edgePaint,
      );
    }
  }

  static void drawWater(Canvas canvas, double x, double y, double w, double h, double animTime) {
    final basePaint = Paint()..color = TeamColors.waterBlue;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), basePaint);
    for (int i = 0; i < 8; i++) {
      final waveX = x + (i / 8) * w;
      final waveY = y + sin(animTime * 1.2 + i * 0.8) * 3;
      final wavePaint = Paint()..color = TeamColors.waterLightBlue.withValues(alpha:  0.3);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(waveX + w / 16, waveY + h / 2), width: w / 6, height: 6),
        wavePaint,
      );
    }
    for (int i = 0; i < 5; i++) {
      final foamX = x + rng.nextDouble() * w;
      final foamY = y + rng.nextDouble() * h;
      final foamPaint = Paint()..color = TeamColors.waterFoam.withValues(alpha:  0.2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(foamX, foamY + sin(animTime + i) * 2), width: 12, height: 4),
        foamPaint,
      );
    }
  }

  static void drawHealthBar(Canvas canvas, Vector2 position, double currentHp, double maxHp, double width, Team team) {
    final hpPercent = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
    final scale = 3.0;
    final barWidth = width * scale;
    final barHeight = 6.0 * scale;
    final x = position.x - barWidth / 2;
    final y = position.y - 32.0 * scale;
    final bgPaint = Paint()..color = Colors.black.withValues(alpha:  0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x - scale, y - scale, barWidth + scale * 2, barHeight + scale * 2), Radius.circular(3 * scale)),
      bgPaint,
    );
    final hpColor = hpPercent > 0.6 ? TeamColors.healthGreen : hpPercent > 0.3 ? TeamColors.healthYellow : TeamColors.healthRed;
    final hpPaint = Paint()..color = hpColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth * hpPercent, barHeight), Radius.circular(2 * scale)),
      hpPaint,
    );
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha:  0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barHeight), Radius.circular(2 * scale)),
      borderPaint,
    );
  }

  static final Map<String, Map<String, Color>> _blueHeroColors = {
    'warrior': {'body': const Color(0xFF1565C0), 'accent': const Color(0xFF42A5F5)},
    'mage': {'body': const Color(0xFF283593), 'accent': const Color(0xFF7986CB)},
    'assassin': {'body': const Color(0xFF1A237E), 'accent': const Color(0xFF5C6BC0)},
    'marksman': {'body': const Color(0xFF0277BD), 'accent': const Color(0xFF4FC3F7)},
    'support': {'body': const Color(0xFF00838F), 'accent': const Color(0xFF4DD0E1)},
    'tank': {'body': const Color(0xFF37474F), 'accent': const Color(0xFF78909C)},
  };

  static final Map<String, Map<String, Color>> _redHeroColors = {
    'warrior': {'body': const Color(0xFFC62828), 'accent': const Color(0xFFEF5350)},
    'mage': {'body': const Color(0xFFAD1457), 'accent': const Color(0xFFF06292)},
    'assassin': {'body': const Color(0xFF880E4F), 'accent': const Color(0xFFEC407A)},
    'marksman': {'body': const Color(0xFFD84315), 'accent': const Color(0xFFFF7043)},
    'support': {'body': const Color(0xFFE65100), 'accent': const Color(0xFFFF9800)},
    'tank': {'body': const Color(0xFFBF360C), 'accent': const Color(0xFFFF5722)},
  };

  static final Random rng = Random();
}
