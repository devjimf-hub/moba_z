import 'dart:convert';
import 'package:vector_math/vector_math_64.dart';
import '../utils/constants.dart';
import '../utils/math.dart';
import '../utils/config_manager.dart';
import 'network_manager.dart';
import 'packet_parser.dart';

class ClientEngine {
  final NetworkManager _network;
  final List<ClientHeroState> _heroes = [];
  final List<ClientMinionState> _minions = [];
  final List<ClientProjectileState> _projectiles = [];
  final List<ClientStructureState> _structures = [];
  double _gameTime = 0;
  bool _gameStarted = false;
  Team? _localTeam;
  int _localHeroIndex = 0;
  bool _gameOver = false;
  Team? _winner;
  final Map<int, double> _deathTimers = {};

  List<ClientHeroState> get heroes => _heroes;
  List<ClientMinionState> get minions => _minions;
  List<ClientProjectileState> get projectiles => _projectiles;
  List<ClientStructureState> get structures => _structures;
  double get gameTime => _gameTime;
  bool get gameStarted => _gameStarted;
  Team? get localTeam => _localTeam;
  int get localHeroIndex => _localHeroIndex;
  bool get gameOver => _gameOver;
  Team? get winner => _winner;

  ClientEngine(this._network);

  void setLocalTeam(Team team, int heroIndex) {
    _localTeam = team;
    _localHeroIndex = heroIndex;
  }

  void handlePacket(GamePacket packet) {
    switch (packet.type) {
      case PacketType.gameStart:
        _handleGameStart(packet.data);
        break;
      case PacketType.configSync:
        _handleConfigSync(packet.data);
        break;
      case PacketType.fullState:
        _handleFullState(packet.data);
        break;
      case PacketType.position:
        _handlePosition(packet.data);
        break;
      case PacketType.health:
        _handleHealth(packet.data);
        break;
      case PacketType.death:
        _handleDeath(packet.data);
        break;
      case PacketType.respawn:
        _handleRespawn(packet.data);
        break;
      case PacketType.minionSpawn:
        _handleMinionSpawn(packet.data);
        break;
      case PacketType.structureDamage:
        _handleStructureDamage(packet.data);
        break;
      case PacketType.structureDeath:
        _handleStructureDeath(packet.data);
        break;
      case PacketType.skill:
        _handleSkillEffect(packet.data);
        break;
      case PacketType.gameOver:
        _handleGameOver(packet.data);
        break;
      case PacketType.gold:
        _handleGold(packet.data);
        break;
      case PacketType.kill:
        _handleKill(packet.data);
        break;
      default:
        break;
    }
  }

  void _handleGameStart(String data) {
    final parsed = PacketParser.parseGameStart(data);
    _gameStarted = true;
  }

  void _handleConfigSync(String data) {
    final parsed = PacketParser.parseConfigSync(data);
    if (parsed == null) return;
    try {
      final gameConfig = jsonDecode(parsed['game']!);
      final heroConfig = jsonDecode(parsed['hero']!);
      ConfigManager.applyGameConfig(gameConfig);
      ConfigManager.applyHeroConfig(heroConfig);
    } catch (e) {
      print('Config sync error: $e');
    }
  }

  void _handleFullState(String data) {
    final parsed = PacketParser.parseFullState(data);
    if (parsed == null) return;

    _gameTime = parsed['gameTime'] as double;
    final entityList = parsed['entities'] as List<dynamic>;
    final structList = parsed['structures'] as List<dynamic>;
    final projList = parsed['projectiles'] as List<dynamic>? ?? [];

    for (final e in entityList) {
      final id = e['id'] as int;
      final typeStr = e['type'] as String;
      final team = Team.values[e['team'] as int];
      final pos = Vector2(e['x'] as double, e['y'] as double);
      final hp = e['hp'] as double;
      final maxHp = e['maxHp'] as double;
      final angle = e['angle'] as double;
      final alive = e['alive'] as bool;

      if (typeStr.startsWith('minion_')) {
        final minionIdx = int.parse(typeStr.replaceFirst('minion_', ''));
        final minion = _minions.firstWhere(
          (m) => m.id == id,
          orElse: () {
            final m = ClientMinionState(
              id: id, type: MinionType.values[minionIdx], team: team,
              position: pos.clone(), hp: hp, maxHp: maxHp, alive: alive,
            );
            _minions.add(m);
            return m;
          },
        );
        minion.previousPosition = minion.position.clone();
        minion.position = pos.clone();
        minion.hp = hp;
        minion.maxHp = maxHp;
        minion.angle = angle;
        minion.alive = alive;
        minion.isAttacking = (e['atk'] as bool?) ?? false;
      } else {
        final hero = _heroes.firstWhere(
          (h) => h.id == id,
          orElse: () {
            final h = ClientHeroState(
              id: id, heroKey: typeStr, team: team,
              position: pos.clone(), hp: hp, maxHp: maxHp, alive: alive,
            );
            _heroes.add(h);
            return h;
          },
        );
        hero.previousPosition = hero.position.clone();
        if (_heroes.isNotEmpty && _localHeroIndex >= 0 && _localHeroIndex < _heroes.length && hero.id == _heroes[_localHeroIndex].id) {
          if (hero.position.distanceTo(pos) > 150) {
            hero.position = pos.clone();
          }
        } else {
          hero.position = pos.clone();
          hero.angle = angle;
        }
        hero.hp = hp;
        hero.maxHp = maxHp;
        hero.alive = alive;
        hero.isAttacking = (e['atk'] as bool?) ?? false;
      }
    }

    for (final s in structList) {
      final id = s['id'] as int;
      final typeIdx = s['type'] as int;
      final team = Team.values[s['team'] as int];
      final pos = Vector2(s['x'] as double, s['y'] as double);
      final hp = s['hp'] as double;
      final maxHp = s['maxHp'] as double;
      final alive = s['alive'] as bool;

      final struct = _structures.firstWhere(
        (st) => st.id == id,
        orElse: () {
          final st = ClientStructureState(
            id: id, type: StructureType.values[typeIdx], team: team,
            position: pos.clone(), hp: hp, maxHp: maxHp, alive: alive,
          );
          _structures.add(st);
          return st;
        },
      );
      struct.position = pos.clone();
      struct.hp = hp;
      struct.maxHp = maxHp;
      struct.alive = alive;
    }

    _minions.removeWhere((m) => !entityList.any((e) => e['id'] == m.id));
    _heroes.removeWhere((h) => !entityList.any((e) => e['id'] == h.id));

    _projectiles.clear();
    for (final p in projList) {
      _projectiles.add(ClientProjectileState(
        id: p['id'] as int,
        type: ProjectileType.values[p['type'] as int],
        team: Team.values[p['team'] as int],
        position: Vector2(p['x'] as double, p['y'] as double),
        angle: p['angle'] as double,
        alive: true,
      ));
    }
  }

  void _handlePosition(String data) {
    final parsed = PacketParser.parsePosition(data);
    if (parsed == null) return;
    final id = parsed['id'] as int;
    final hero = _heroes.firstWhere(
      (h) => h.id == id,
      orElse: () => ClientHeroState(
        id: id, heroKey: 'unknown', team: Team.blue,
        position: Vector2(parsed['x'] as double, parsed['y'] as double),
        hp: 0, maxHp: 0, alive: true,
      ),
    );
    if (_heroes.isNotEmpty && _localHeroIndex >= 0 && _localHeroIndex < _heroes.length && hero.id == _heroes[_localHeroIndex].id) {
      final pos = Vector2(parsed['x'] as double, parsed['y'] as double);
      if (hero.position.distanceTo(pos) > 150) {
        hero.position = pos;
      }
    } else {
      hero.position = Vector2(parsed['x'] as double, parsed['y'] as double);
      hero.angle = parsed['angle'] as double;
    }
  }

  void _handleHealth(String data) {
    final parsed = PacketParser.parseHealth(data);
    if (parsed == null) return;
    final id = parsed['id'] as int;
    final hp = parsed['hp'] as double;
    for (final h in _heroes) {
      if (h.id == id) { h.hp = hp; return; }
    }
    for (final m in _minions) {
      if (m.id == id) { m.hp = hp; return; }
    }
    for (final s in _structures) {
      if (s.id == id) { s.hp = hp; return; }
    }
  }

  void _handleDeath(String data) {
    final parsed = PacketParser.parseDeath(data);
    if (parsed == null) return;
    final id = parsed['id'] as int;
    for (final h in _heroes) {
      if (h.id == id) { h.alive = false; h.hp = 0; return; }
    }
    for (final m in _minions) {
      if (m.id == id) { m.alive = false; m.hp = 0; return; }
    }
    for (final s in _structures) {
      if (s.id == id) { s.alive = false; s.hp = 0; return; }
    }
  }

  void _handleRespawn(String data) {
    final parsed = PacketParser.parseRespawn(data);
    if (parsed == null) return;
    final id = parsed['id'] as int;
    final time = parsed['time'] as double;
    _deathTimers[id] = time;
    for (final h in _heroes) {
      if (h.id == id) {
        h.respawnTimer = time;
        return;
      }
    }
  }

  void _handleMinionSpawn(String data) {
    final parsed = PacketParser.parseMinionSpawn(data);
    if (parsed == null) return;
    final id = parsed['id'] as int;
    if (_minions.any((m) => m.id == id)) return;
    _minions.add(ClientMinionState(
      id: id,
      type: parsed['type'] as MinionType,
      team: parsed['team'] as Team,
      position: Vector2(parsed['x'] as double, parsed['y'] as double),
      hp: parsed['type'] == MinionType.melee
          ? GameConstants.meleeMinionHp
          : parsed['type'] == MinionType.ranged
              ? GameConstants.rangedMinionHp
              : GameConstants.siegeMinionHp,
      maxHp: parsed['type'] == MinionType.melee
          ? GameConstants.meleeMinionHp
          : parsed['type'] == MinionType.ranged
              ? GameConstants.rangedMinionHp
              : GameConstants.siegeMinionHp,
      alive: true,
    ));
  }

  void _handleStructureDamage(String data) {
    final parsed = PacketParser.parseStructureDamage(data);
    if (parsed == null) return;
    for (final s in _structures) {
      if (s.id == parsed['id']) {
        s.hp = parsed['hp'] as double;
        return;
      }
    }
  }

  void _handleStructureDeath(String data) {
    final parsed = PacketParser.parseStructureDeath(data);
    if (parsed == null) return;
    for (final s in _structures) {
      if (s.id == parsed['id']) {
        s.alive = false;
        s.hp = 0;
        return;
      }
    }
  }

  void _handleSkillEffect(String data) {
    final parsed = PacketParser.parseSkill(data);
    if (parsed == null) return;
    final id = parsed['id'] as int;
    final hero = _heroes.firstWhere(
      (h) => h.id == id,
      orElse: () => ClientHeroState(
        id: id, heroKey: 'unknown', team: Team.blue,
        position: Vector2.zero(), hp: 0, maxHp: 0, alive: false,
      ),
    );
    if (hero.alive) {
      hero.angle = GameMath.angleTo(
        hero.position,
        Vector2(parsed['tx'] as double, parsed['ty'] as double),
      );
    }
  }

  void _handleGameOver(String data) {
    final parsed = PacketParser.parseGameOver(data);
    if (parsed == null) return;
    _gameOver = true;
    _winner = parsed['winner'] as Team;
  }

  void _handleGold(String data) {
    final parsed = PacketParser.parseGold(data);
    if (parsed == null) return;
    final id = parsed['id'] as int;
    final gold = parsed['gold'] as int;
    for (final h in _heroes) {
      if (h.id == id) { h.gold = gold; return; }
    }
  }

  void _handleKill(String data) {
    final parsed = PacketParser.parseKill(data);
    if (parsed == null) return;
    final heroId = parsed['hero'] as int;
    final victimId = parsed['victim'] as int;
    final gold = parsed['gold'] as int;
    for (final h in _heroes) {
      if (h.id == heroId) { h.kills++; h.gold = gold; }
      if (h.id == victimId) { h.deaths++; }
    }
  }

  void update(double dt, double moveX, double moveY) {
    _gameTime += dt;
    for (final h in _heroes) {
      if (!h.alive && h.respawnTimer > 0) {
        h.respawnTimer = (h.respawnTimer - dt).clamp(0.0, 99.0);
      }
      for (final key in h.cooldowns.keys) {
        h.cooldowns[key] = (h.cooldowns[key]! - dt).clamp(0.0, 99.0);
      }
    }

    if (_localHeroIndex >= 0 && _localHeroIndex < _heroes.length) {
      final hero = _heroes[_localHeroIndex];
      if (hero.alive && (moveX != 0 || moveY != 0)) {
        final heroDef = HeroDefinitions.heroes[hero.heroKey];
        if (heroDef != null) {
          final moveSpeed = (heroDef['moveSpeed'] as num).toDouble();
          final dir = Vector2(moveX, moveY)..normalize();
          final newPos = hero.position + dir * moveSpeed * dt;
          hero.position = GameMath.clampToWorld(newPos, GameConstants.worldWidth, GameConstants.worldHeight, 20);
          hero.angle = GameMath.angleTo(Vector2.zero(), dir);
        }
      }
    }
  }

  void sendInput(double moveX, double moveY, bool attacking, List<int> skills) {
    if (skills.isNotEmpty && _localHeroIndex < _heroes.length) {
      final hero = _heroes[_localHeroIndex];
      final heroDef = HeroDefinitions.heroes[hero.heroKey];
      final skillDefs = heroDef?['skills'] as Map<String, dynamic>?;
      for (final skillIdx in skills) {
        String? skillKey;
        switch (skillIdx) {
          case 1: skillKey = 'skill1'; break;
          case 2: skillKey = 'skill2'; break;
          case 3: skillKey = 'ultimate'; break;
        }
        if (skillKey != null && skillDefs != null) {
          final skillData = skillDefs[skillKey] as Map<String, dynamic>?;
          if (skillData != null && (hero.cooldowns[skillKey] ?? 0) <= 0) {
            hero.cooldowns[skillKey] = (skillData['cooldown'] as num).toDouble();
          }
        }
      }
    }
    _network.sendToHost(GamePacket(
      type: PacketType.playerInput,
      data: PacketParser.encodePlayerInput(_localHeroIndex, moveX, moveY, attacking, skills),
    ));
  }
}

class ClientHeroState {
  final int id;
  final String heroKey;
  final Team team;
  Vector2 position;
  Vector2 previousPosition;
  double hp;
  double maxHp;
  double angle = 0;
  bool alive;
  double respawnTimer = 0;
  bool isAttacking = false;
  final Map<String, double> cooldowns = {};
  int gold = 500;
  int kills = 0;
  int deaths = 0;

  ClientHeroState({
    required this.id,
    required this.heroKey,
    required this.team,
    required this.position,
    required this.hp,
    required this.maxHp,
    required this.alive,
  }) : previousPosition = position.clone();
}

class ClientMinionState {
  final int id;
  final MinionType type;
  final Team team;
  Vector2 position;
  Vector2 previousPosition;
  double hp;
  double maxHp;
  double angle = 0;
  bool alive;
  bool isAttacking = false;

  ClientMinionState({
    required this.id,
    required this.type,
    required this.team,
    required this.position,
    required this.hp,
    required this.maxHp,
    required this.alive,
  }) : previousPosition = position.clone();
}

class ClientStructureState {
  final int id;
  final StructureType type;
  final Team team;
  Vector2 position;
  double hp;
  double maxHp;
  bool alive;

  ClientStructureState({
    required this.id,
    required this.type,
    required this.team,
    required this.position,
    required this.hp,
    required this.maxHp,
    required this.alive,
  });
}

class ClientProjectileState {
  final int id;
  Vector2 position;
  double angle;
  ProjectileType type;
  Team team;
  bool alive;

  ClientProjectileState({
    required this.id,
    required this.position,
    required this.angle,
    required this.type,
    required this.team,
    required this.alive,
  });
}
