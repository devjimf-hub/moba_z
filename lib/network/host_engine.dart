import 'package:vector_math/vector_math_64.dart';
import '../utils/constants.dart';
import '../utils/math.dart';
import 'network_manager.dart';
import 'packet_parser.dart';

class HostEngine {
  final NetworkManager _network;
  final List<HeroState> _heroes = [];
  final List<MinionState> _minions = [];
  final List<ProjectileState> _projectiles = [];
  final List<StructureState> _structures = [];
  double _gameTime = 0;
  double _minionTimer = 0;
  double _broadcastTimer = 0;
  int _waveCount = 0;
  int _entityIdCounter = 1000;
  bool _gameOver = false;
  Team? _winner;
  final Map<int, PlayerInputState> _playerInputs = {};
  final Map<String, int> _peerHeroMap = {};

  List<HeroState> get heroes => _heroes;
  List<MinionState> get minions => _minions;
  List<ProjectileState> get projectiles => _projectiles;
  List<StructureState> get structures => _structures;
  double get gameTime => _gameTime;
  bool get gameOver => _gameOver;
  Team? get winner => _winner;

  HostEngine(this._network);

  void initializeGame(List<Map<String, dynamic>> playerSelections, {String? clientPeerId}) {
    _network.sendPacket(GamePacket(
      type: PacketType.gameStart,
      data: PacketParser.encodeGameStart(_generateSeed()),
    ));

    for (int i = 0; i < playerSelections.length; i++) {
      final sel = playerSelections[i];
      final heroId = _nextId();
      final team = sel['team'] as Team;
      final heroKey = sel['hero'] as String;
      final pos = team == Team.blue
          ? Vector2(GameConstants.crystalBlueX + 60, GameConstants.crystalBlueY)
          : Vector2(GameConstants.crystalRedX - 60, GameConstants.crystalRedY + 60);

      final heroDef = HeroDefinitions.heroes[heroKey]!;
      _heroes.add(HeroState(
        id: heroId,
        heroKey: heroKey,
        team: team,
        position: pos.clone(),
        hp: (heroDef['hp'] as num).toDouble(),
        maxHp: (heroDef['hp'] as num).toDouble(),
        mana: (heroDef['mana'] as num).toDouble(),
        maxMana: (heroDef['mana'] as num).toDouble(),
        moveSpeed: (heroDef['moveSpeed'] as num).toDouble(),
        attackRange: (heroDef['attackRange'] as num).toDouble(),
        damage: (heroDef['baseDamage'] as num).toDouble(),
        attackSpeed: (heroDef['attackSpeed'] as num).toDouble(),
        armor: (heroDef['armor'] as num).toDouble(),
        magicResist: (heroDef['magicResist'] as num).toDouble(),
        alive: true,
      ));

      if (i == 0) {
        _peerHeroMap['local'] = 0;
      } else if (clientPeerId != null) {
        _peerHeroMap[clientPeerId] = i;
      }
    }

    _spawnStructures(Team.blue);
    _spawnStructures(Team.red);
  }

  void _spawnStructures(Team team) {
    final isBlue = team == Team.blue;
    
    // Turret positions for diagonal MOBA layout (Blue bottom-left, Red top-right)
    // Top lane: along left edge (x=400) and top edge (y=400)
    final topOuter = isBlue ? Vector2(400, 1300) : Vector2(1300, 400);
    final topInner = isBlue ? Vector2(400, 1900) : Vector2(1900, 400);
    final topBase = isBlue ? Vector2(400, 2500) : Vector2(2500, 400);

    // Mid lane: diagonal through center
    final midOuter = isBlue ? Vector2(1300, 1900) : Vector2(1900, 1300);
    final midInner = isBlue ? Vector2(1000, 2200) : Vector2(2200, 1000);
    final midBase = isBlue ? Vector2(700, 2500) : Vector2(2500, 700);

    // Bot lane: along bottom edge (y=2800) and right edge (x=2800)
    final botOuter = isBlue ? Vector2(1900, 2800) : Vector2(2800, 1900);
    final botInner = isBlue ? Vector2(1300, 2800) : Vector2(2800, 1300);
    final botBase = isBlue ? Vector2(700, 2800) : Vector2(2800, 700);

    void addTurret(Vector2 pos, StructureType type) {
      final isOuter = type == StructureType.outerTurret;
      final isInner = type == StructureType.innerTurret;
      final hp = isOuter ? GameConstants.turretOuterHp : (isInner ? GameConstants.turretInnerHp : GameConstants.turretBaseHp);
      final range = isOuter ? GameConstants.turretOuterRange : (isInner ? GameConstants.turretInnerRange : GameConstants.turretBaseRange);
      
      _structures.add(StructureState(
        id: _nextId(), type: type, team: team,
        position: pos, hp: hp, maxHp: hp, range: range, alive: true,
      ));
    }

    addTurret(topOuter, StructureType.outerTurret);
    addTurret(midOuter, StructureType.outerTurret);
    addTurret(botOuter, StructureType.outerTurret);

    addTurret(topInner, StructureType.innerTurret);
    addTurret(midInner, StructureType.innerTurret);
    addTurret(botInner, StructureType.innerTurret);

    addTurret(topBase, StructureType.baseTurret);
    addTurret(midBase, StructureType.baseTurret);
    addTurret(botBase, StructureType.baseTurret);

    final crystalX = isBlue ? GameConstants.crystalBlueX : GameConstants.crystalRedX;
    final crystalY = isBlue ? GameConstants.crystalBlueY : GameConstants.crystalRedY;
    _structures.add(StructureState(
      id: _nextId(), type: StructureType.crystal, team: team,
      position: Vector2(crystalX, crystalY),
      hp: GameConstants.crystalHp, maxHp: GameConstants.crystalHp,
      range: 0, alive: true,
    ));
  }

  void update(double dt) {
    if (_gameOver) return;
    _gameTime += dt;
    _minionTimer += dt;

    if (_minionTimer >= GameConstants.minionSpawnInterval) {
      _minionTimer -= GameConstants.minionSpawnInterval;
      _waveCount++;
      _spawnMinionWave();
    }

    for (final hero in _heroes) {
      if (!hero.alive) {
        hero.respawnTimer -= dt;
        if (hero.respawnTimer <= 0) {
          hero.alive = true;
          hero.hp = hero.maxHp;
          hero.mana = hero.maxMana;
          final isBlue = hero.team == Team.blue;
          hero.position = Vector2(
            isBlue ? GameConstants.crystalBlueX + 60 : GameConstants.crystalRedX - 60,
            isBlue ? GameConstants.crystalBlueY : GameConstants.crystalRedY + 60,
          );
        }
        continue;
      }
      _updateHero(hero, dt);
    }

    for (final minion in _minions) {
      if (!minion.alive) continue;
      _updateMinion(minion, dt);
    }

    for (final struct in _structures) {
      if (!struct.alive) continue;
      _updateStructure(struct, dt);
    }

    _resolveCollisions();

    _updateProjectiles(dt);
    _processProjectileHits();
    _cleanupDead();
    _broadcastTimer += dt;
    if (_broadcastTimer >= 1.0 / GameConstants.networkTickRate) {
      _broadcastTimer = 0;
      _broadcastState();
    }
  }

  void _resolveCollisions() {
    final allEntities = <EntityState>[];
    allEntities.addAll(_heroes.where((h) => h.alive));
    allEntities.addAll(_minions.where((m) => m.alive));
    
    // Simple O(N^2) separation
    for (int i = 0; i < allEntities.length; i++) {
      for (int j = i + 1; j < allEntities.length; j++) {
        final a = allEntities[i];
        final b = allEntities[j];
        final diff = a.position - b.position;
        final dist2 = diff.length2;
        final minDist = 80.0; // Collision distance threshold for scaled entities
        if (dist2 > 0.01 && dist2 < minDist * minDist) {
          final dist = diff.length;
          final overlap = minDist - dist;
          final push = (diff / dist) * (overlap * 0.1); // Soft push
          a.position += push;
          b.position -= push;
        }
      }
    }
  }

  void _updateHero(HeroState hero, double dt) {
    hero.previousPosition = hero.position.clone();
    final input = _playerInputs[hero.id];
    if (input == null) return;

    if (input.moveX != 0 || input.moveY != 0) {
      final dir = Vector2(input.moveX, input.moveY)..normalize();
      final newPos = hero.position + dir * hero.moveSpeed * dt;
      hero.position = GameMath.clampToWorld(newPos, GameConstants.worldWidth, GameConstants.worldHeight, 20);
      hero.angle = GameMath.angleTo(Vector2.zero(), dir);
    }

    for (final skillIdx in input.pendingSkills) {
      _useHeroSkill(hero, skillIdx);
    }
    input.pendingSkills.clear();

    if (hero.attackCooldown <= 0) {
      final target = _findNearestValidTarget(hero.position, hero.team, hero.attackRange);
      if (target != null) {
        hero.angle = GameMath.angleTo(hero.position, target.position);
        _fireProjectile(hero.position, target.position, hero.damage, ProjectileType.basicAttack, hero.team, hero.id, target.id);
        hero.attackCooldown = 1.0 / hero.attackSpeed;
      }
    }
    hero.attackCooldown = (hero.attackCooldown - dt).clamp(0.0, 99.0);

    for (final skill in hero.cooldowns.keys) {
      hero.cooldowns[skill] = (hero.cooldowns[skill]! - dt).clamp(0.0, 99.0);
    }

    hero.gold += (GameConstants.baseGoldPerSecond * dt).toInt();
  }

  void _useHeroSkill(HeroState hero, int skillIndex) {
    final heroDef = HeroDefinitions.heroes[hero.heroKey];
    if (heroDef == null) return;
    final skills = heroDef['skills'] as Map<String, dynamic>;
    String skillKey;
    switch (skillIndex) {
      case 1: skillKey = 'skill1'; break;
      case 2: skillKey = 'skill2'; break;
      case 3: skillKey = 'ultimate'; break;
      default: return;
    }
    final skillData = skills[skillKey] as Map<String, dynamic>?;
    if (skillData == null) return;
    if (hero.cooldowns[skillKey] != null && hero.cooldowns[skillKey]! > 0) return;

    final skillDamage = (skillData['damage'] as num).toDouble();
    final manaCost = skillDamage.abs() * 0.1;
    if (hero.mana < manaCost) return;
    hero.mana -= manaCost;
    hero.cooldowns[skillKey] = (skillData['cooldown'] as num).toDouble();

    final skillRange = (skillData['range'] as num).toDouble();
    final target = _findNearestEnemy(hero.position, hero.team, skillRange);
    if (target != null) {
      _fireProjectile(hero.position, target.position, skillDamage, ProjectileType.skill, hero.team, hero.id, target.id);
    }

    _network.broadcastToClients(GamePacket(
      type: PacketType.skill,
      data: PacketParser.encodeSkill(hero.id, skillKey, target?.position),
    ));
  }

  void _spawnMinionWave() {
    final isSiege = _waveCount % GameConstants.siegeWaveInterval == 0;

    for (final team in Team.values) {
      final isBlue = team == Team.blue;
      final bx = isBlue ? GameConstants.crystalBlueX : GameConstants.crystalRedX;
      final by = isBlue ? GameConstants.crystalBlueY : GameConstants.crystalRedY;

      for (final lane in ['top', 'mid', 'bot']) {
        // Spawn each lane's minions at a lane-specific offset from base so they diverge immediately
        double spawnX, spawnY;
        if (isBlue) {
          if (lane == 'top') { spawnX = bx + 20; spawnY = by - 60; }
          else if (lane == 'mid') { spawnX = bx + 60; spawnY = by - 20; }
          else { spawnX = bx + 80; spawnY = by; }
        } else {
          if (lane == 'top') { spawnX = bx - 80; spawnY = by; }
          else if (lane == 'mid') { spawnX = bx - 60; spawnY = by + 20; }
          else { spawnX = bx - 20; spawnY = by + 60; }
        }
        for (int i = 0; i < GameConstants.meleeMinionsPerWave; i++) {
          final id = _nextId();
          final pos = Vector2(spawnX + GameMath.randomRange(-40, 40), spawnY + GameMath.randomRange(-40, 40));
          _minions.add(MinionState(
            id: id, type: MinionType.melee, team: team, lane: lane,
            position: pos, hp: GameConstants.meleeMinionHp, maxHp: GameConstants.meleeMinionHp,
            damage: GameConstants.meleeMinionDamage, moveSpeed: GameConstants.meleeMinionSpeed,
            attackRange: GameConstants.meleeMinionRange, alive: true,
          ));
          _network.broadcastToClients(GamePacket(
            type: PacketType.minionSpawn,
            data: PacketParser.encodeMinionSpawn(id, MinionType.melee, team, pos),
          ));
        }
        for (int i = 0; i < GameConstants.rangedMinionsPerWave; i++) {
          final id = _nextId();
          final pos = Vector2(spawnX + GameMath.randomRange(-40, 40), spawnY + GameMath.randomRange(-40, 40));
          _minions.add(MinionState(
            id: id, type: MinionType.ranged, team: team, lane: lane,
            position: pos, hp: GameConstants.rangedMinionHp, maxHp: GameConstants.rangedMinionHp,
            damage: GameConstants.rangedMinionDamage, moveSpeed: GameConstants.rangedMinionSpeed,
            attackRange: GameConstants.rangedMinionRange, alive: true,
          ));
          _network.broadcastToClients(GamePacket(
            type: PacketType.minionSpawn,
            data: PacketParser.encodeMinionSpawn(id, MinionType.ranged, team, pos),
          ));
        }
        if (isSiege) {
          final id = _nextId();
          final pos = Vector2(spawnX + GameMath.randomRange(-20, 20), spawnY);
          _minions.add(MinionState(
            id: id, type: MinionType.siege, team: team, lane: lane,
            position: pos, hp: GameConstants.siegeMinionHp, maxHp: GameConstants.siegeMinionHp,
            damage: GameConstants.siegeMinionDamage, moveSpeed: GameConstants.siegeMinionSpeed,
            attackRange: GameConstants.siegeMinionRange, alive: true,
          ));
          _network.broadcastToClients(GamePacket(
            type: PacketType.minionSpawn,
            data: PacketParser.encodeMinionSpawn(id, MinionType.siege, team, pos),
          ));
        }
      }
    }
  }

  void _updateMinion(MinionState minion, double dt) {
    minion.previousPosition = minion.position.clone();
    final enemyHero = _findNearestEnemy(minion.position, minion.team, GameConstants.minionAggroRange);
    final enemyTurret = _findNearestTurret(minion.position, minion.team, GameConstants.minionAggroRange);
    final enemyCrystal = _findEnemyCrystal(minion.position, minion.team, GameConstants.minionAggroRange);

    EntityState? attackTarget;
    if (enemyTurret != null) {
      attackTarget = enemyTurret;
    } else if (enemyHero != null) {
      attackTarget = enemyHero;
    } else if (enemyCrystal != null && enemyCrystal.alive) {
      attackTarget = enemyCrystal;
    }

    if (attackTarget != null && GameMath.distance(minion.position, attackTarget.position) <= minion.attackRange) {
      minion.angle = GameMath.angleTo(minion.position, attackTarget.position);
      minion.attackTimer -= dt;
      if (minion.attackTimer <= 0) {
        attackTarget.hp -= minion.damage;
        minion.attackTimer = 1.0;
        _network.broadcastToClients(GamePacket(
          type: PacketType.health,
          data: PacketParser.encodeHealth(attackTarget.id, attackTarget.hp, attackTarget.maxHp),
        ));
        if (attackTarget.hp <= 0) {
          _handleEntityDeath(attackTarget);
        }
      }
    } else {
      final moveTarget = attackTarget?.position ?? _getMinionLaneTarget(minion);
      final dir = GameMath.directionTo(minion.position, moveTarget);
      minion.position = minion.position + dir * minion.moveSpeed * dt;
      minion.position = GameMath.clampToWorld(minion.position, GameConstants.worldWidth, GameConstants.worldHeight, 10);
      minion.angle = GameMath.angleTo(Vector2.zero(), dir);
    }
  }

  Vector2 _getMinionLaneTarget(MinionState minion) {
    final isBlue = minion.team == Team.blue;
    final waypoints = isBlue ? _getBlueWaypoints(minion.lane) : _getRedWaypoints(minion.lane);
    
    if (minion.currentWaypoint >= waypoints.length) {
      final crystalX = isBlue ? GameConstants.crystalRedX : GameConstants.crystalBlueX;
      final crystalY = isBlue ? GameConstants.crystalRedY : GameConstants.crystalBlueY;
      return Vector2(crystalX, crystalY);
    }
    
    final target = waypoints[minion.currentWaypoint];
    if (GameMath.distance(minion.position, target) < 100) {
      minion.currentWaypoint++;
      if (minion.currentWaypoint >= waypoints.length) {
         final crystalX = isBlue ? GameConstants.crystalRedX : GameConstants.crystalBlueX;
         final crystalY = isBlue ? GameConstants.crystalRedY : GameConstants.crystalBlueY;
         return Vector2(crystalX, crystalY);
      }
      return waypoints[minion.currentWaypoint];
    }
    return target;
  }

  List<Vector2> _getBlueWaypoints(String lane) {
    if (lane == 'top') return [
      Vector2(GameConstants.blueBaseX, 1200),
      Vector2(1200, GameConstants.redBaseY),
      Vector2(GameConstants.redBaseX, GameConstants.redBaseY),
    ];
    if (lane == 'mid') return [
      Vector2(GameConstants.worldWidth / 2, GameConstants.worldHeight / 2),
      Vector2(GameConstants.redBaseX, GameConstants.redBaseY),
    ];
    return [
      Vector2(2000, GameConstants.blueBaseY),
      Vector2(GameConstants.redBaseX, 2000),
      Vector2(GameConstants.redBaseX, GameConstants.redBaseY),
    ];
  }

  List<Vector2> _getRedWaypoints(String lane) {
    if (lane == 'top') return [
      Vector2(1200, GameConstants.redBaseY),
      Vector2(GameConstants.blueBaseX, 1200),
      Vector2(GameConstants.blueBaseX, GameConstants.blueBaseY),
    ];
    if (lane == 'mid') return [
      Vector2(GameConstants.worldWidth / 2, GameConstants.worldHeight / 2),
      Vector2(GameConstants.blueBaseX, GameConstants.blueBaseY),
    ];
    return [
      Vector2(GameConstants.redBaseX, 2000),
      Vector2(2000, GameConstants.blueBaseY),
      Vector2(GameConstants.blueBaseX, GameConstants.blueBaseY),
    ];
  }

  void _updateStructure(StructureState struct, double dt) {
    struct.attackTimer -= dt;
    if (struct.attackTimer > 0) return;

    final target = _findNearestEnemy(struct.position, struct.team, struct.range);
    if (target != null) {
      _fireProjectile(struct.position, target.position, GameConstants.turretDamage, ProjectileType.turret, struct.team, struct.id, target.id);
      struct.attackTimer = 1.0 / GameConstants.turretAttackSpeed;
    }
  }

  void _fireProjectile(Vector2 from, Vector2 target, double damage, ProjectileType type, Team team, int sourceId, int targetId) {
    final id = _nextId();
    final dir = GameMath.directionTo(from, target);
    final lifetime = type == ProjectileType.turret ? 1.5 : 3.0;
    _projectiles.add(ProjectileState(
      id: id, position: from.clone(), velocity: dir * GameConstants.projectileSpeed,
      damage: damage, type: type, team: team,
      sourceId: sourceId, targetId: targetId, alive: true,
      lifetime: lifetime,
    ));
  }

  void _updateProjectiles(double dt) {
    for (final proj in _projectiles) {
      if (!proj.alive) continue;
      proj.previousPosition = proj.position.clone();
      proj.position = proj.position + proj.velocity * dt;
      proj.lifetime -= dt;
      if (proj.lifetime <= 0 || !GameMath.pointInRect(proj.position, 0, 0, GameConstants.worldWidth, GameConstants.worldHeight)) {
        proj.alive = false;
      }
    }
  }

  void _processProjectileHits() {
    for (final proj in _projectiles) {
      if (!proj.alive) continue;
      final target = _findEntityById(proj.targetId);
      if (target == null) continue;
      final hit = GameMath.distance(proj.position, target.position) < 25;
      if (hit) {
        target.hp -= proj.damage;
        proj.alive = false;
        _network.broadcastToClients(GamePacket(
          type: PacketType.health,
          data: PacketParser.encodeHealth(target.id, target.hp, target.maxHp),
        ));
        if (target.hp <= 0) {
          _handleEntityDeath(target, killerId: proj.sourceId);
        }
      }
    }
  }

  void _handleEntityDeath(EntityState entity, {int killerId = -1}) {
    entity.alive = false;
    entity.hp = 0;

    _network.broadcastToClients(GamePacket(
      type: PacketType.death,
      data: PacketParser.encodeDeath(entity.id, killerId),
    ));

    if (entity is StructureState) {
      _network.broadcastToClients(GamePacket(
        type: PacketType.structureDeath,
        data: PacketParser.encodeStructureDeath(entity.id),
      ));
      if (entity.type != StructureType.crystal) {
        final killer = _findHeroById(killerId);
        if (killer != null) {
          killer.gold += GameConstants.goldPerTurretKill;
          _network.broadcastToClients(GamePacket(
            type: PacketType.gold,
            data: PacketParser.encodeGold(killer.id, killer.gold),
          ));
        }
      }
      if (entity.type == StructureType.crystal) {
        final winner = entity.team == Team.blue ? Team.red : Team.blue;
        _gameOver = true;
        _winner = winner;
        _network.broadcastToClients(GamePacket(
          type: PacketType.gameOver,
          data: PacketParser.encodeGameOver(winner),
        ));
      }
    }

    if (entity is MinionState) {
      final killer = _findHeroById(killerId);
      if (killer != null) {
        killer.gold += GameConstants.goldPerMinionKill;
        _network.broadcastToClients(GamePacket(
          type: PacketType.gold,
          data: PacketParser.encodeGold(killer.id, killer.gold),
        ));
      }
    }

    if (entity is HeroState) {
      entity.deaths++;
      entity.respawnTimer = GameConstants.respawnBaseTime;
      final killer = _findHeroById(killerId);
      if (killer != null) {
        killer.kills++;
        killer.gold += GameConstants.goldPerHeroKill;
        _network.broadcastToClients(GamePacket(
          type: PacketType.kill,
          data: PacketParser.encodeKill(killer.id, entity.id, killer.gold),
        ));
      }
      _network.broadcastToClients(GamePacket(
        type: PacketType.respawn,
        data: PacketParser.encodeRespawn(entity.id, entity.respawnTimer),
      ));
    }
  }

  HeroState? _findHeroById(int id) {
    for (final h in _heroes) {
      if (h.id == id) return h;
    }
    return null;
  }

  void _cleanupDead() {
    _minions.removeWhere((m) => !m.alive);
    _projectiles.removeWhere((p) => !p.alive);
  }

  EntityState? _findEntityById(int id) {
    for (final h in _heroes) {
      if (h.id == id) return h;
    }
    for (final m in _minions) {
      if (m.id == id) return m;
    }
    for (final s in _structures) {
      if (s.id == id) return s;
    }
    return null;
  }

  EntityState? _findNearestEnemy(Vector2 pos, Team myTeam, double range) {
    double bestDist = range;
    EntityState? best;
    for (final h in _heroes) {
      if (!h.alive || h.team == myTeam) continue;
      final d = GameMath.distance(pos, h.position);
      if (d < bestDist) { bestDist = d; best = h; }
    }
    for (final m in _minions) {
      if (!m.alive || m.team == myTeam) continue;
      final d = GameMath.distance(pos, m.position);
      if (d < bestDist) { bestDist = d; best = m; }
    }
    return best;
  }

  EntityState? _findNearestValidTarget(Vector2 pos, Team myTeam, double range) {
    double bestDist = range;
    EntityState? best;
    for (final h in _heroes) {
      if (!h.alive || h.team == myTeam) continue;
      final d = GameMath.distance(pos, h.position);
      if (d < bestDist) { bestDist = d; best = h; }
    }
    for (final m in _minions) {
      if (!m.alive || m.team == myTeam) continue;
      final d = GameMath.distance(pos, m.position);
      if (d < bestDist) { bestDist = d; best = m; }
    }
    for (final s in _structures) {
      if (!s.alive || s.team == myTeam) continue;
      final d = GameMath.distance(pos, s.position);
      if (d < bestDist) { bestDist = d; best = s; }
    }
    return best;
  }

  StructureState? _findNearestTurret(Vector2 pos, Team myTeam, double range) {
    double bestDist = range;
    StructureState? best;
    for (final s in _structures) {
      if (!s.alive || s.team == myTeam) continue;
      if (s.type == StructureType.crystal) continue;
      final d = GameMath.distance(pos, s.position);
      if (d < bestDist) { bestDist = d; best = s; }
    }
    return best;
  }

  StructureState? _findEnemyCrystal(Vector2 pos, Team myTeam, double range) {
    for (final s in _structures) {
      if (s.team != myTeam && s.type == StructureType.crystal) {
        if (GameMath.distance(pos, s.position) <= range) return s;
      }
    }
    return null;
  }

  void _broadcastState() {
    final entityData = _heroes.map((h) => {
      'id': h.id, 'type': h.heroKey, 'team': h.team.index,
      'x': h.position.x, 'y': h.position.y,
      'hp': h.hp, 'maxHp': h.maxHp,
      'angle': h.angle, 'alive': h.alive, 'atk': h.attackCooldown > 0,
    }).toList();
    for (final m in _minions) {
      entityData.add({
        'id': m.id, 'type': 'minion_${m.type.index}', 'team': m.team.index,
        'x': m.position.x, 'y': m.position.y,
        'hp': m.hp, 'maxHp': m.maxHp,
        'angle': m.angle, 'alive': m.alive,
        'atk': m.attackTimer > 0,
      });
    }
    final structData = <Map<String, dynamic>>[];
    for (final s in _structures) {
      structData.add({
        'id': s.id, 'type': s.type.index, 'team': s.team.index,
        'x': s.position.x, 'y': s.position.y,
        'hp': s.hp, 'maxHp': s.maxHp, 'alive': s.alive,
      });
    }
    _network.broadcastToClients(GamePacket(
      type: PacketType.fullState,
      data: PacketParser.encodeFullState(entityData, structData, _gameTime),
    ));
  }

  void setPeerHero(String peerId, int heroIdx) {
    _peerHeroMap[peerId] = heroIdx;
  }

  void handlePlayerInput(String peerId, Map<String, dynamic> input) {
    int heroIdx;
    if (_peerHeroMap.containsKey(peerId)) {
      heroIdx = _peerHeroMap[peerId]!;
    } else {
      heroIdx = input['hero'] as int? ?? 0;
    }
    if (heroIdx < 0 || heroIdx >= _heroes.length) return;
    final hero = _heroes[heroIdx];
    _playerInputs[hero.id] = PlayerInputState(
      moveX: (input['mx'] as num).toDouble(),
      moveY: (input['my'] as num).toDouble(),
      attacking: input['attacking'] as bool? ?? false,
      pendingSkills: (input['skills'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
    );
  }

  int _nextId() => _entityIdCounter++;
  int _generateSeed() => DateTime.now().millisecondsSinceEpoch;
}

class HeroState extends EntityState {
  final String heroKey;
  double mana;
  double maxMana;
  double moveSpeed;
  double attackRange;
  double damage;
  double attackSpeed;
  double armor;
  double magicResist;
  double attackCooldown = 0;
  double respawnTimer = 0;
  int level = 1;
  int gold = 500;
  int kills = 0;
  int deaths = 0;
  final Map<String, double> cooldowns = {};

  HeroState({
    required int id,
    required this.heroKey,
    required Team team,
    required Vector2 position,
    required double hp,
    required double maxHp,
    required this.mana,
    required this.maxMana,
    required this.moveSpeed,
    required this.attackRange,
    required this.damage,
    required this.attackSpeed,
    required this.armor,
    required this.magicResist,
    required bool alive,
  }) : super(id: id, team: team, position: position, hp: hp, maxHp: maxHp, alive: alive);
}

class MinionState extends EntityState {
  final MinionType type;
  final String lane;
  int currentWaypoint = 0;
  double moveSpeed;
  double attackRange;
  double damage;
  double attackTimer = 0;

  MinionState({
    required int id,
    required this.type,
    required Team team,
    required this.lane,
    required Vector2 position,
    required double hp,
    required double maxHp,
    required this.damage,
    required this.moveSpeed,
    required this.attackRange,
    required bool alive,
  }) : super(id: id, team: team, position: position, hp: hp, maxHp: maxHp, alive: alive);
}

class StructureState extends EntityState {
  final StructureType type;
  double range;
  double attackTimer = 0;

  StructureState({
    required int id,
    required this.type,
    required Team team,
    required Vector2 position,
    required double hp,
    required double maxHp,
    required this.range,
    required bool alive,
  }) : super(id: id, team: team, position: position, hp: hp, maxHp: maxHp, alive: alive);
}

class ProjectileState {
  final int id;
  Vector2 position;
  Vector2 previousPosition = Vector2.zero();
  Vector2 velocity;
  double damage;
  ProjectileType type;
  Team team;
  int sourceId;
  int targetId;
  bool alive;
  double lifetime;

  ProjectileState({
    required this.id,
    required this.position,
    required this.velocity,
    required this.damage,
    required this.type,
    required this.team,
    required this.sourceId,
    required this.targetId,
    required this.alive,
    this.lifetime = 3.0,
  });
}

class EntityState {
  final int id;
  final Team team;
  Vector2 position;
  Vector2? previousPosition;
  double hp;
  double maxHp;
  double angle = 0;
  bool alive;

  EntityState({
    required this.id,
    required this.team,
    required this.position,
    required this.hp,
    required this.maxHp,
    required this.alive,
  });
}

class PlayerInputState {
  double moveX;
  double moveY;
  bool attacking;
  List<int> pendingSkills;

  PlayerInputState({
    required this.moveX,
    required this.moveY,
    required this.attacking,
    required this.pendingSkills,
  });
}
