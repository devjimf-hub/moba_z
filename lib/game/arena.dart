import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../utils/constants.dart';
import '../utils/collision.dart';
import '../utils/math.dart';

class Arena {
  final List<TreeObject> trees = [];
  final List<BushZone> bushes = [];
  final List<Obstacle> obstacles = [];
  final List<LanePath> lanes = [];
  final Random _rng = Random(42);

  ui.Image? _mapImage;

  Arena() {
    _generateLanes();
    _generateTrees();
    _generateBushes();
    _loadMapImage();
  }

  Future<void> _loadMapImage() async {
    try {
      final data = await rootBundle.load('assets/images/moba_arena_map.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      _mapImage = frameInfo.image;
    } catch (e) {
      debugPrint('Failed to load map image: $e');
    }
  }

  void _generateLanes() {
    // Top Lane: Blue base -> up left edge -> across top -> Red base
    final topWaypoints = [
      Vector2(GameConstants.blueBaseX, GameConstants.blueBaseY),
      Vector2(GameConstants.blueBaseX, 1200),
      Vector2(1200, GameConstants.redBaseY),
      Vector2(GameConstants.redBaseX, GameConstants.redBaseY),
    ];

    // Mid Lane: Blue base -> center -> Red base (direct diagonal)
    final midWaypoints = [
      Vector2(GameConstants.blueBaseX, GameConstants.blueBaseY),
      Vector2(GameConstants.worldWidth / 2, GameConstants.worldHeight / 2),
      Vector2(GameConstants.redBaseX, GameConstants.redBaseY),
    ];

    // Bot Lane: Blue base -> across bottom -> up right edge -> Red base
    final botWaypoints = [
      Vector2(GameConstants.blueBaseX, GameConstants.blueBaseY),
      Vector2(2000, GameConstants.blueBaseY),
      Vector2(GameConstants.redBaseX, 2000),
      Vector2(GameConstants.redBaseX, GameConstants.redBaseY),
    ];

    lanes.add(LanePath(waypoints: topWaypoints, name: 'top'));
    lanes.add(LanePath(waypoints: midWaypoints, name: 'mid'));
    lanes.add(LanePath(waypoints: botWaypoints, name: 'bot'));
  }

  void _generateTrees() {
    // Fill jungle areas between lanes and around edges
    for (int i = 0; i < 300; i++) {
      final x = 200 + _rng.nextDouble() * (GameConstants.worldWidth - 400);
      final y = 200 + _rng.nextDouble() * (GameConstants.worldHeight - 400);
      final pos = Vector2(x, y);

      if (!_isOnLane(pos) && !_isOnRiver(pos) && !_isInBase(pos)) {
        final radius = 12.0 + _rng.nextDouble() * 10;
        trees.add(TreeObject(position: pos, radius: radius));
        obstacles.add(Obstacle(position: pos, radius: radius * 0.5));
      }
    }

    final borderTrees = <Vector2>[];
    for (double x = 80; x < GameConstants.worldWidth - 80; x += 80) {
      borderTrees.add(Vector2(x, 40));
      borderTrees.add(Vector2(x, GameConstants.worldHeight - 40));
    }
    for (double y = 80; y < GameConstants.worldHeight - 80; y += 80) {
      borderTrees.add(Vector2(40, y));
      borderTrees.add(Vector2(GameConstants.worldWidth - 40, y));
    }
    for (final pos in borderTrees) {
      trees.add(TreeObject(position: pos, radius: 18));
      obstacles.add(Obstacle(position: pos, radius: 12));
    }
  }

  void _generateBushes() {
    final bushPositions = [
      // River bushes (top-left side)
      Vector2(1000, 1000),
      Vector2(1200, 1200),
      // River bushes (bottom-right side)
      Vector2(2000, 2000),
      Vector2(2200, 2200),
      // Top jungle bushes
      Vector2(800, 2000),
      Vector2(1000, 1800),
      Vector2(1800, 1000),
      Vector2(2000, 800),
      // Bot jungle bushes
      Vector2(800, 2400),
      Vector2(1800, 2600),
      Vector2(2400, 1800),
      Vector2(2600, 1200),
    ];

    for (final pos in bushPositions) {
      final radius = 45.0 + _rng.nextDouble() * 25;
      bushes.add(BushZone(position: pos, radius: radius));
    }
  }

  bool _isOnLane(Vector2 pos) {
    for (final lane in lanes) {
      for (int i = 0; i < lane.waypoints.length - 1; i++) {
        final p1 = lane.waypoints[i];
        final p2 = lane.waypoints[i + 1];
        final dist = GameMath.distanceToLineSegment(pos, p1, p2);
        if (dist < GameConstants.laneWidth / 2 + 50) return true;
      }
    }
    return false;
  }

  bool _isOnRiver(Vector2 pos) {
    final dist = GameMath.distanceToLineSegment(
      pos,
      Vector2(400, 400),
      Vector2(2800, 2800),
    );
    return dist < 200;
  }

  bool _isInBase(Vector2 pos) {
    final blueDist = GameMath.distance(pos, Vector2(GameConstants.blueBaseX, GameConstants.blueBaseY));
    final redDist = GameMath.distance(pos, Vector2(GameConstants.redBaseX, GameConstants.redBaseY));
    return blueDist < 500 || redDist < 500;
  }

  void render(Canvas canvas, double animTime, {bool isMirrored = false}) {
    if (_mapImage != null) {
      canvas.save();
      if (isMirrored) {
        canvas.translate(GameConstants.worldWidth / 2, GameConstants.worldHeight / 2);
        canvas.rotate(pi);
        canvas.translate(-GameConstants.worldWidth / 2, -GameConstants.worldHeight / 2);
      }
      canvas.drawImageRect(
        _mapImage!,
        Rect.fromLTWH(0, 0, _mapImage!.width.toDouble(), _mapImage!.height.toDouble()),
        Rect.fromLTWH(0, 0, GameConstants.worldWidth, GameConstants.worldHeight),
        Paint(),
      );
      canvas.restore();
    } else {
      _drawGround(canvas);
      _drawRiver(canvas, animTime);
      _drawLanes(canvas);
      _drawBases(canvas);
      _drawBushes(canvas, animTime);
      for (final tree in trees) {
        _drawTree(canvas, tree, animTime);
      }
    }
  }

  void _drawGround(Canvas canvas) {
    final groundPaint = Paint()..color = const Color(0xFF4A7C3F);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, GameConstants.worldWidth, GameConstants.worldHeight),
      groundPaint,
    );
    final rng = Random(123);
    for (int i = 0; i < 200; i++) {
      final x = rng.nextDouble() * GameConstants.worldWidth;
      final y = rng.nextDouble() * GameConstants.worldHeight;
      final grassPaint = Paint()..color = Color.fromARGB(30, 30 + rng.nextInt(40), 100 + rng.nextInt(50), 20 + rng.nextInt(30));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 20 + rng.nextDouble() * 40, height: 15 + rng.nextDouble() * 30),
        grassPaint,
      );
    }
  }

  void _drawRiver(Canvas canvas, double animTime) {
    final riverPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 350.0
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(400, 400)
      ..lineTo(2800, 2800);

    canvas.drawPath(path, riverPaint);

    // River waves
    for (int i = 1; i <= 20; i++) {
      final t = i / 21;
      final offset = sin(animTime * 1.2 + i * 0.7) * 20;
      final waveX = 400 + t * 2400 + offset;
      final waveY = 400 + t * 2400 - offset;

      final wavePaint = Paint()..color = const Color(0xFF42A5F5).withValues(alpha:  0.3);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(waveX - offset, waveY + offset),
          width: 60,
          height: 12,
        ),
        wavePaint,
      );
    }
  }

  void _drawLanes(Canvas canvas) {
    for (final lane in lanes) {
      _drawLanePath(canvas, lane);
    }
  }

  void _drawLanePath(Canvas canvas, LanePath lane) {
    final pathPaint = Paint()
      ..color = const Color(0xFF795548).withValues(alpha:  0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = GameConstants.laneWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(lane.waypoints.first.x, lane.waypoints.first.y);
    for (int i = 1; i < lane.waypoints.length; i++) {
      path.lineTo(lane.waypoints[i].x, lane.waypoints[i].y);
    }
    canvas.drawPath(path, pathPaint);
  }

  void _drawBases(Canvas canvas) {
    _drawBlueBase(canvas);
    _drawRedBase(canvas);
  }

  void _drawBlueBase(Canvas canvas) {
    final basePaint = Paint()..color = const Color(0xFF1565C0).withValues(alpha:  0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(GameConstants.blueBaseX, GameConstants.blueBaseY),
          width: 500, height: 500,
        ),
        const Radius.circular(20),
      ),
      basePaint,
    );

    final borderPaint = Paint()
      ..color = const Color(0xFF2196F3).withValues(alpha:  0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(GameConstants.blueBaseX, GameConstants.blueBaseY),
          width: 500, height: 500,
        ),
        const Radius.circular(20),
      ),
      borderPaint,
    );

    _drawSpawnArea(canvas, Vector2(GameConstants.crystalBlueX + 60, GameConstants.crystalBlueY));
  }

  void _drawRedBase(Canvas canvas) {
    final basePaint = Paint()..color = const Color(0xFFC62828).withValues(alpha:  0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(GameConstants.redBaseX, GameConstants.redBaseY),
          width: 500, height: 500,
        ),
        const Radius.circular(20),
      ),
      basePaint,
    );

    final borderPaint = Paint()
      ..color = const Color(0xFFF44336).withValues(alpha:  0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(GameConstants.redBaseX, GameConstants.redBaseY),
          width: 500, height: 500,
        ),
        const Radius.circular(20),
      ),
      borderPaint,
    );

    _drawSpawnArea(canvas, Vector2(GameConstants.crystalRedX - 60, GameConstants.crystalRedY));
  }

  void _drawSpawnArea(Canvas canvas, Vector2 pos) {
    final spawnPaint = Paint()..color = Colors.white.withValues(alpha:  0.15);
    canvas.drawCircle(Offset(pos.x, pos.y), 60, spawnPaint);
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha:  0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(pos.x, pos.y), 80, glowPaint);
  }

  void _drawBushes(Canvas canvas, double animTime) {
    for (final bush in bushes) {
      final sway = sin(animTime * 1.5 + bush.position.x * 0.02) * 3;
      final bushPaint = Paint()..color = const Color(0xFF2E7D32).withValues(alpha:  0.85);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bush.position.x + sway, bush.position.y),
          width: bush.radius * 2.2,
          height: bush.radius * 1.4,
        ),
        bushPaint,
      );
      final lightPaint = Paint()..color = const Color(0xFF43A047).withValues(alpha:  0.6);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bush.position.x + sway + 5, bush.position.y - 3),
          width: bush.radius * 1.4,
          height: bush.radius * 0.8,
        ),
        lightPaint,
      );
    }
  }

  void _drawTree(Canvas canvas, TreeObject tree, double animTime) {
    final sway = sin(animTime * 0.8 + tree.position.x * 0.01) * 2;
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha:  0.25);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(tree.position.x + 4, tree.position.y + 18), width: 24, height: 12),
      shadowPaint,
    );
    final trunkPaint = Paint()..color = const Color(0xFF4E342E);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(tree.position.x, tree.position.y + 6), width: 8, height: 20),
      trunkPaint,
    );
    final foliagePaint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawCircle(Offset(tree.position.x + sway, tree.position.y - 12), tree.radius, foliagePaint);
    final darkPaint = Paint()..color = const Color(0xFF1B5E20);
    canvas.drawCircle(Offset(tree.position.x + sway - 6, tree.position.y - 8), tree.radius * 0.7, darkPaint);
    final lightPaint = Paint()..color = const Color(0xFF43A047);
    canvas.drawCircle(Offset(tree.position.x + sway + 8, tree.position.y - 16), tree.radius * 0.4, lightPaint);
  }
}

class TreeObject {
  final Vector2 position;
  final double radius;

  TreeObject({required this.position, required this.radius});
}
