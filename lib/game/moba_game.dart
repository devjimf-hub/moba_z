import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../utils/constants.dart';
import '../utils/math.dart';
import '../assets/procedural_assets.dart';
import '../network/network_manager.dart';
import '../network/host_engine.dart';
import '../network/client_engine.dart';
import '../network/packet_parser.dart';
import 'arena.dart';
import 'camera.dart';

class MobaGame {
  final bool isHost;
  final NetworkManager network;
  late final Arena arena;
  late final GameCamera gameCamera;
  HostEngine? hostEngine;
  ClientEngine? clientEngine;
  double _gameTime = 0;
  double _sendTimer = 0;
  double _animTime = 0;
  final List<FloatingDamageNumber> _floatingNumbers = [];
  final List<HitEffect> _hitEffects = [];
  Team? _gameWinner;
  bool _gameOverTriggered = false;
  ui.Size _viewSize = const ui.Size(800, 600);
  
  double get gameTime => _gameTime;
  double get ping => network.ping;
  double get networkQuality => network.getNetworkQuality();

  // Host always plays Team.blue; the joining client always plays Team.red
  // (see lobby.dart). Red's view is rendered mirrored 180° so both players
  // perceive their own base as bottom-left and "forward" as up-right,
  // matching the map-inversion perspective used by mobile MOBAs.
  Team? get localTeam => isHost ? Team.blue : clientEngine?.localTeam;
  bool get isMirrored => localTeam == Team.red;

  double _moveX = 0;
  double _moveY = 0;
  bool _isAttacking = false;
  final List<int> _pendingSkills = [];

  MobaGame({required this.isHost, required this.network}) {
    ProceduralAssets.loadAssets();
    arena = Arena();
    gameCamera = GameCamera();
    if (isHost) {
      hostEngine = HostEngine(network);
    } else {
      clientEngine = ClientEngine(network);
    }

    network.onPacketReceived = (packet) {
      if (isHost && hostEngine != null) {
        if (packet.type == PacketType.playerInput) {
          final parsed = PacketParser.parsePlayerInput(packet.data);
          if (parsed != null) {
            hostEngine!.handlePlayerInput('remote', parsed);
          }
        }
      } else if (!isHost && clientEngine != null) {
        clientEngine!.handlePacket(packet);
      }
    };
  }

  void initializeGame(List<Map<String, dynamic>> selections, {String? clientPeerId}) {
    hostEngine?.initializeGame(selections, clientPeerId: clientPeerId);
  }

  void setLocalTeam(Team team, int heroIndex) {
    clientEngine?.setLocalTeam(team, heroIndex);
  }

  void setMoveInput(double mx, double my) {
    _moveX = mx;
    _moveY = my;
  }

  void setAttackInput(bool attacking) {
    _isAttacking = attacking;
  }

  void useSkill(int skillIndex) {
    _pendingSkills.add(skillIndex);
  }

  void update(double dt) {
    _animTime += dt;
    _gameTime += dt;

    if (isHost && hostEngine != null) {
      hostEngine!.update(dt);
      if (hostEngine!.gameOver && !_gameOverTriggered) {
        _gameWinner = hostEngine!.winner;
        _gameOverTriggered = true;
      }
    } else if (clientEngine != null) {
      final sendMx = isMirrored ? -_moveX : _moveX;
      final sendMy = isMirrored ? -_moveY : _moveY;
      clientEngine!.update(dt, sendMx, sendMy);
      if (clientEngine!.gameOver && !_gameOverTriggered) {
        _gameWinner = clientEngine!.winner;
        _gameOverTriggered = true;
      }
    }

    _sendTimer += dt;
    if (_sendTimer >= 1.0 / GameConstants.networkTickRate) {
      _sendTimer = 0;
      if (!isHost && clientEngine != null) {
        // The joystick direction is relative to the player's (possibly
        // mirrored) screen, so it must be un-mirrored back into world space
        // before being sent to the host as a movement direction.
        final sendMx = isMirrored ? -_moveX : _moveX;
        final sendMy = isMirrored ? -_moveY : _moveY;
        clientEngine!.sendInput(
          sendMx,
          sendMy,
          _isAttacking,
          List<int>.from(_pendingSkills),
        );
        _pendingSkills.clear();
      }
      if (isHost && hostEngine != null) {
        hostEngine!.handlePlayerInput('local', {
          'hero': 0,
          'mx': _moveX,
          'my': _moveY,
          'attacking': _isAttacking,
          'skills': List<int>.from(_pendingSkills),
        });
        _pendingSkills.clear();
      }
    }

    _updateFloatingNumbers(dt);
    _updateHitEffects(dt);
    _updateCamera(dt);
  }

  void _updateCamera(double dt) {
    if (isHost && hostEngine != null && hostEngine!.heroes.isNotEmpty) {
      final hero = hostEngine!.heroes.first;
      if (hero.alive) {
        gameCamera.follow(hero.position);
      }
    } else if (clientEngine != null && clientEngine!.heroes.isNotEmpty) {
      final idx = clientEngine!.localHeroIndex.clamp(0, clientEngine!.heroes.length - 1);
      final hero = clientEngine!.heroes[idx];
      if (hero.alive) {
        gameCamera.follow(hero.position);
      }
    }
    gameCamera.update(dt);
  }

  void _updateFloatingNumbers(double dt) {
    _floatingNumbers.removeWhere((f) => f.timer <= 0);
    for (final f in _floatingNumbers) {
      f.timer -= dt;
      f.position.y -= 40 * dt;
    }
  }

  void _updateHitEffects(double dt) {
    _hitEffects.removeWhere((e) => e.timer <= 0);
    for (final e in _hitEffects) {
      e.timer -= dt;
    }
  }

  void addFloatingNumber(Vector2 pos, double amount, bool isCrit) {
    _floatingNumbers.add(
      FloatingDamageNumber(
        position: pos.clone(),
        amount: amount,
        isCrit: isCrit,
        timer: 1.0,
      ),
    );
  }

  void addHitEffect(Vector2 pos, Color color) {
    _hitEffects.add(HitEffect(position: pos.clone(), color: color, timer: 0.3));
  }

  void setViewSize(double width, double height) {
    _viewSize = ui.Size(width, height);
    gameCamera.setViewportSize(width, height);
  }

  void render(Canvas canvas) {
    final bgColor = Paint()..color = const Color(0xFF2D5A27);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, _viewSize.width, _viewSize.height),
      bgColor,
    );

    canvas.save();
    gameCamera.applyTransform(canvas);

    if (isMirrored) {
      // Perspective mirroring / map inversion: rotate the whole scene 180°
      // around the camera's focal point (the local hero) so this player
      // always sees their own base at the bottom-left and advances "up",
      // just like the other team does on their own screen.
      final cx = gameCamera.position.x;
      final cy = gameCamera.position.y;
      canvas.translate(cx, cy);
      canvas.rotate(pi);
      canvas.translate(-cx, -cy);
    }

    arena.render(canvas, _animTime, isMirrored: isMirrored);

    if (isHost && hostEngine != null) {
      _renderHostState(canvas);
    } else if (clientEngine != null) {
      _renderClientState(canvas);
    }

    _renderHitEffects(canvas);
    _renderFloatingNumbers(canvas);

    canvas.restore();

    _renderMiniMap(canvas);
    _renderGameOverlay(canvas);
  }

  // Draws a billboard-style overlay (health bar, damage number) so it stays
  // upright and readable even when the world is rendered mirrored.
  void _drawUpright(Canvas canvas, Vector2 position, void Function() draw) {
    if (!isMirrored) {
      draw();
      return;
    }
    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.rotate(pi);
    canvas.translate(-position.x, -position.y);
    draw();
    canvas.restore();
  }

  void _renderHostState(Canvas canvas) {
    final engine = hostEngine!;
    for (final struct in engine.structures) {
      if (struct.alive) {
        if (struct.type == StructureType.crystal) {
          ProceduralAssets.drawCrystal(
            canvas,
            struct.position,
            struct.team,
            true,
            struct.hp / struct.maxHp,
            _animTime,
            isMirrored: isMirrored,
          );
        } else {
          ProceduralAssets.drawTurret(
            canvas,
            struct.position,
            struct.team,
            struct.type,
            true,
            _animTime,
            isMirrored: isMirrored,
          );
        }
        _drawUpright(canvas, struct.position, () => ProceduralAssets.drawHealthBar(
          canvas,
          struct.position,
          struct.hp,
          struct.maxHp,
          48,
          struct.team,
        ));
      } else {
        _renderDestroyedStructure(canvas, struct);
      }
    }

    for (final minion in engine.minions) {
      if (minion.alive) {
        final m = minion as dynamic;
        final bool isAttacking = m.attackTimer > 0;
        final bool isMoving = !isAttacking;
        ProceduralAssets.drawMinion(
          canvas,
          minion.type,
          minion.position,
          minion.angle,
          minion.team,
          true,
          _animTime,
          isMoving: isMoving,
          isAttacking: isAttacking,
          isMirrored: isMirrored,
        );
        _drawUpright(canvas, minion.position, () => ProceduralAssets.drawHealthBar(
          canvas,
          minion.position,
          minion.hp,
          minion.maxHp,
          30,
          minion.team,
        ));
      }
    }

    for (final hero in engine.heroes) {
      if (hero.alive) {
        final h = hero as dynamic;
        final bool isAttacking = h.attackCooldown > 0;
        final bool isMoving = h.previousPosition != null ? (h.position - h.previousPosition).length2 > 0.01 : false;
        ProceduralAssets.drawHero(
          canvas,
          hero.heroKey,
          hero.position,
          hero.angle,
          _animTime,
          true,
          hero.team,
          isMoving: isMoving,
          isAttacking: isAttacking,
          isMirrored: isMirrored,
        );
        _drawUpright(canvas, hero.position, () => ProceduralAssets.drawHealthBar(
          canvas,
          hero.position,
          hero.hp,
          hero.maxHp,
          48,
          hero.team,
        ));
      }
    }

    for (final proj in engine.projectiles) {
      if (proj.alive) {
        ProceduralAssets.drawProjectile(
          canvas,
          proj.position,
          GameMath.angleTo(proj.previousPosition, proj.position),
          proj.type,
          proj.team,
          isMirrored: isMirrored,
        );
      }
    }
  }

  void _renderClientState(Canvas canvas) {
    final engine = clientEngine!;
    for (final struct in engine.structures) {
      if (struct.alive) {
        if (struct.type == StructureType.crystal) {
          ProceduralAssets.drawCrystal(
            canvas,
            struct.position,
            struct.team,
            true,
            struct.hp / struct.maxHp,
            _animTime,
            isMirrored: isMirrored,
          );
        } else {
          ProceduralAssets.drawTurret(
            canvas,
            struct.position,
            struct.team,
            struct.type,
            true,
            _animTime,
            isMirrored: isMirrored,
          );
        }
        _drawUpright(canvas, struct.position, () => ProceduralAssets.drawHealthBar(
          canvas,
          struct.position,
          struct.hp,
          struct.maxHp,
          48,
          struct.team,
        ));
      } else {
        _renderDestroyedStructure(canvas, struct);
      }
    }

    for (final minion in engine.minions) {
      if (minion.alive) {
        final m = minion as dynamic;
        final bool isAttacking = m.isAttacking == true;
        final bool isMoving = m.previousPosition != null ? (m.position - m.previousPosition).length2 > 0.01 : false;
        ProceduralAssets.drawMinion(
          canvas,
          minion.type,
          minion.position,
          minion.angle,
          minion.team,
          true,
          _animTime,
          isMoving: isMoving,
          isAttacking: isAttacking,
          isMirrored: isMirrored,
        );
        _drawUpright(canvas, minion.position, () => ProceduralAssets.drawHealthBar(
          canvas,
          minion.position,
          minion.hp,
          minion.maxHp,
          30,
          minion.team,
        ));
      }
    }

    for (final hero in engine.heroes) {
      if (hero.alive) {
        final h = hero as dynamic;
        final bool isAttacking = h.isAttacking == true;
        final bool isMoving = h.previousPosition != null ? (h.position - h.previousPosition).length2 > 0.01 : false;
        ProceduralAssets.drawHero(
          canvas,
          hero.heroKey,
          hero.position,
          hero.angle,
          _animTime,
          true,
          hero.team,
          isMoving: isMoving,
          isAttacking: isAttacking,
          isMirrored: isMirrored,
        );
        _drawUpright(canvas, hero.position, () => ProceduralAssets.drawHealthBar(
          canvas,
          hero.position,
          hero.hp,
          hero.maxHp,
          48,
          hero.team,
        ));
      }
    }

    for (final proj in engine.projectiles) {
      if (proj.alive) {
        ProceduralAssets.drawProjectile(
          canvas,
          proj.position,
          proj.angle,
          proj.type,
          proj.team,
          isMirrored: isMirrored,
        );
      }
    }
  }

  void _renderDestroyedStructure(Canvas canvas, dynamic struct) {
    final rubblePaint = Paint()
      ..color = const Color(0xFF757575).withValues(alpha: 0.5);
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(struct.position.x, struct.position.y + 5),
        width: 40,
        height: 15,
      ),
      rubblePaint,
    );
    for (int i = 0; i < 5; i++) {
      final rx = struct.position.x + GameMath.randomRange(-15, 15);
      final ry = struct.position.y + GameMath.randomRange(-5, 10);
      final stonePaint = Paint()
        ..color = const Color(0xFF616161).withValues(alpha: 0.4);
      canvas.drawRect(
        ui.Rect.fromCenter(center: ui.Offset(rx, ry), width: 6, height: 4),
        stonePaint,
      );
    }
  }

  void _renderHitEffects(Canvas canvas) {
    for (final effect in _hitEffects) {
      final alpha = (effect.timer / 0.3).clamp(0.0, 1.0);
      for (int i = 0; i < 6; i++) {
        final angle = (i / 6) * pi * 2;
        final dist = (0.3 - effect.timer) * 80;
        final px = effect.position.x + cos(angle) * dist;
        final py = effect.position.y + sin(angle) * dist;
        final sparkPaint = Paint()..color = effect.color.withValues(alpha: alpha);
        canvas.drawCircle(ui.Offset(px, py), 3 * alpha, sparkPaint);
      }
      final glowPaint = Paint()
        ..color = effect.color.withValues(alpha: alpha * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(
        ui.Offset(effect.position.x, effect.position.y),
        20 * (1 - alpha),
        glowPaint,
      );
    }
  }

  void _renderFloatingNumbers(Canvas canvas) {
    for (final num in _floatingNumbers) {
      final alpha = num.timer.clamp(0.0, 1.0);
      final scale = num.isCrit ? 1.5 : 1.0;
      final textPainter = TextPainter(
        text: TextSpan(
          text: num.amount > 0
              ? '-${num.amount.toInt()}'
              : '+${num.amount.abs().toInt()}',
          style: TextStyle(
            color: num.amount > 0
                ? (num.isCrit ? const Color(0xFFFF1744) : Colors.white)
                : const Color(0xFF4CAF50),
            fontSize: 14 * scale,
            fontWeight: num.isCrit ? FontWeight.bold : FontWeight.normal,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: alpha * 0.8),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      _drawUpright(canvas, num.position, () => textPainter.paint(
        canvas,
        ui.Offset(
          num.position.x - textPainter.width / 2,
          num.position.y - textPainter.height / 2,
        ),
      ));
    }
  }

  void _renderMiniMap(Canvas canvas) {
    final mmW = GameConstants.minimapWidth;
    final mmH = GameConstants.minimapHeight;
    final mmX = GameConstants.minimapPadding;
    final mmY = GameConstants.minimapPadding;
    final scaleX = mmW / GameConstants.worldWidth;
    final scaleY = mmH / GameConstants.worldHeight;

    final bgPaint = Paint()..color = const Color(0xFF1B2E1B).withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(mmX, mmY, mmW, mmH),
        const Radius.circular(6),
      ),
      bgPaint,
    );
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(mmX, mmY, mmW, mmH),
        const Radius.circular(6),
      ),
      borderPaint,
    );

    final riverPaint = Paint()
      ..color = TeamColors.waterBlue.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = GameConstants.riverWidth * scaleX;
    canvas.drawLine(
      ui.Offset(mmX + 400 * scaleX, mmY + 400 * scaleY),
      ui.Offset(mmX + 2800 * scaleX, mmY + 2800 * scaleY),
      riverPaint,
    );

    final entities = <dynamic>[];
    if (isHost && hostEngine != null) {
      entities.addAll(hostEngine!.heroes);
      entities.addAll(hostEngine!.minions);
      entities.addAll(hostEngine!.structures);
    } else if (clientEngine != null) {
      entities.addAll(clientEngine!.heroes);
      entities.addAll(clientEngine!.minions);
      entities.addAll(clientEngine!.structures);
    }

    for (final entity in entities) {
      // The minimap is a fixed top-down view of the world, so mirrored
      // players see it flipped the same 180° as their main view: their own
      // base stays anchored bottom-left, matching the main camera.
      final displayPos = isMirrored
          ? GameMath.mirrorPoint(entity.position, GameConstants.worldWidth, GameConstants.worldHeight)
          : entity.position;
      final ex = mmX + displayPos.x * scaleX;
      final ey = mmY + displayPos.y * scaleY;
      final dotColor = entity.team == Team.blue
          ? TeamColors.blueTeam
          : TeamColors.redTeam;
      final dotPaint = Paint()
        ..color = entity.alive ? dotColor : dotColor.withValues(alpha: 0.3);
      final isHero = entity is HeroState || entity is ClientHeroState;
      final dotSize = isHero ? 4.0 : 2.0;
      canvas.drawCircle(ui.Offset(ex, ey), dotSize, dotPaint);
    }

    final viewRect = gameCamera.getVisibleRect();
    final displayViewRect = isMirrored
        ? ui.Rect.fromLTRB(
            GameConstants.worldWidth - viewRect.right,
            GameConstants.worldHeight - viewRect.bottom,
            GameConstants.worldWidth - viewRect.left,
            GameConstants.worldHeight - viewRect.top,
          )
        : viewRect;
    final vrx = mmX + displayViewRect.left * scaleX;
    final vry = mmY + displayViewRect.top * scaleY;
    final vrw = displayViewRect.width * scaleX;
    final vrh = displayViewRect.height * scaleY;
    final viewPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(ui.Rect.fromLTWH(vrx, vry, vrw, vrh), viewPaint);
  }

  void _renderGameOverlay(Canvas canvas) {
    if (_gameOverTriggered && _gameWinner != null) {
      final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, _viewSize.width, _viewSize.height),
        overlayPaint,
      );

      final isVictory = (_gameWinner == localTeam);
      final color = isVictory
          ? const Color(0xFFFFD700)
          : const Color(0xFFF44336);
      final textPainter = TextPainter(
        text: TextSpan(
          text: isVictory ? 'VICTORY' : 'DEFEAT',
          style: TextStyle(
            color: color,
            fontSize: 64,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.8),
                offset: const Offset(3, 3),
                blurRadius: 5,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        ui.Offset(
          _viewSize.width / 2 - textPainter.width / 2,
          _viewSize.height / 2 - textPainter.height / 2,
        ),
      );
    }
  }

  void zoomIn() => gameCamera.zoomIn();
  void zoomOut() => gameCamera.zoomOut();

  Map<String, dynamic> getLocalHeroStats() {
    if (isHost && hostEngine != null && hostEngine!.heroes.isNotEmpty) {
      final hero = hostEngine!.heroes.first;
      final heroDef = HeroDefinitions.heroes[hero.heroKey];
      final skillDefs = heroDef?['skills'] as Map<String, dynamic>?;
      double skill1Cd = 0, skill1Max = 5;
      double skill2Cd = 0, skill2Max = 8;
      double ultCd = 0, ultMax = 15;
      if (skillDefs != null) {
        final s1 = skillDefs['skill1'] as Map<String, dynamic>?;
        final s2 = skillDefs['skill2'] as Map<String, dynamic>?;
        final ult = skillDefs['ultimate'] as Map<String, dynamic>?;
        if (s1 != null) { skill1Cd = hero.cooldowns['skill1'] ?? 0; skill1Max = (s1['cooldown'] as num).toDouble(); }
        if (s2 != null) { skill2Cd = hero.cooldowns['skill2'] ?? 0; skill2Max = (s2['cooldown'] as num).toDouble(); }
        if (ult != null) { ultCd = hero.cooldowns['ultimate'] ?? 0; ultMax = (ult['cooldown'] as num).toDouble(); }
      }
      return {
        'hp': hero.hp, 'maxHp': hero.maxHp,
        'mana': hero.mana, 'maxMana': hero.maxMana,
        'gold': hero.gold, 'kills': hero.kills, 'deaths': hero.deaths,
        'skill1Cooldown': skill1Cd, 'skill1MaxCooldown': skill1Max,
        'skill2Cooldown': skill2Cd, 'skill2MaxCooldown': skill2Max,
        'ultimateCooldown': ultCd, 'ultimateMaxCooldown': ultMax,
      };
    } else if (clientEngine != null && clientEngine!.heroes.isNotEmpty) {
      final idx = clientEngine!.localHeroIndex.clamp(0, clientEngine!.heroes.length - 1);
      final hero = clientEngine!.heroes[idx];
      final heroDef = HeroDefinitions.heroes[hero.heroKey];
      final skillDefs = heroDef?['skills'] as Map<String, dynamic>?;
      double skill1Cd = 0, skill1Max = 5;
      double skill2Cd = 0, skill2Max = 8;
      double ultCd = 0, ultMax = 15;
      if (skillDefs != null) {
        final s1 = skillDefs['skill1'] as Map<String, dynamic>?;
        final s2 = skillDefs['skill2'] as Map<String, dynamic>?;
        final ult = skillDefs['ultimate'] as Map<String, dynamic>?;
        if (s1 != null) { skill1Cd = hero.cooldowns['skill1'] ?? 0; skill1Max = (s1['cooldown'] as num).toDouble(); }
        if (s2 != null) { skill2Cd = hero.cooldowns['skill2'] ?? 0; skill2Max = (s2['cooldown'] as num).toDouble(); }
        if (ult != null) { ultCd = hero.cooldowns['ultimate'] ?? 0; ultMax = (ult['cooldown'] as num).toDouble(); }
      }
      return {
        'hp': hero.hp, 'maxHp': hero.maxHp,
        'mana': 0.0, 'maxMana': 0.0,
        'gold': hero.gold, 'kills': hero.kills, 'deaths': hero.deaths,
        'skill1Cooldown': skill1Cd, 'skill1MaxCooldown': skill1Max,
        'skill2Cooldown': skill2Cd, 'skill2MaxCooldown': skill2Max,
        'ultimateCooldown': ultCd, 'ultimateMaxCooldown': ultMax,
      };
    }
    return {'hp': 0.0, 'maxHp': 100.0, 'mana': 0.0, 'maxMana': 100.0, 'gold': 0, 'kills': 0, 'deaths': 0};
  }

  void dispose() {
    network.dispose();
  }
}

class FloatingDamageNumber {
  Vector2 position;
  final double amount;
  final bool isCrit;
  double timer;

  FloatingDamageNumber({
    required this.position,
    required this.amount,
    required this.isCrit,
    required this.timer,
  });
}

class HitEffect {
  final Vector2 position;
  final Color color;
  double timer;

  HitEffect({required this.position, required this.color, required this.timer});
}
