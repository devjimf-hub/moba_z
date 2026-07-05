import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ConfigManager {
  static const String _gameConfigKey = 'moba_game_config';
  static const String _heroConfigKey = 'moba_hero_config';

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final gameConfigStr = prefs.getString(_gameConfigKey);
    if (gameConfigStr != null) {
      try {
        final Map<String, dynamic> gameConfig = jsonDecode(gameConfigStr);
        applyGameConfig(gameConfig);
      } catch (e) {
        print('Error loading game config: $e');
      }
    }
    
    final heroConfigStr = prefs.getString(_heroConfigKey);
    if (heroConfigStr != null) {
      try {
        final Map<String, dynamic> heroConfig = jsonDecode(heroConfigStr);
        applyHeroConfig(heroConfig);
      } catch (e) {
        print('Error loading hero config: $e');
      }
    }
  }

  static Future<void> saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final gameConfig = extractGameConfig();
    final heroConfig = extractHeroConfig();
    
    await prefs.setString(_gameConfigKey, jsonEncode(gameConfig));
    await prefs.setString(_heroConfigKey, jsonEncode(heroConfig));
  }

  static Map<String, dynamic> extractGameConfig() {
    return {
      'worldWidth': GameConstants.worldWidth,
      'worldHeight': GameConstants.worldHeight,
      'blueBaseX': GameConstants.blueBaseX,
      'blueBaseY': GameConstants.blueBaseY,
      'redBaseX': GameConstants.redBaseX,
      'redBaseY': GameConstants.redBaseY,
      'crystalBlueX': GameConstants.crystalBlueX,
      'crystalBlueY': GameConstants.crystalBlueY,
      'crystalRedX': GameConstants.crystalRedX,
      'crystalRedY': GameConstants.crystalRedY,
      'turretOuterRange': GameConstants.turretOuterRange,
      'turretInnerRange': GameConstants.turretInnerRange,
      'turretBaseRange': GameConstants.turretBaseRange,
      'turretOuterHp': GameConstants.turretOuterHp,
      'turretInnerHp': GameConstants.turretInnerHp,
      'turretBaseHp': GameConstants.turretBaseHp,
      'turretDamage': GameConstants.turretDamage,
      'turretAttackSpeed': GameConstants.turretAttackSpeed,
      'crystalHp': GameConstants.crystalHp,
      'minionSpawnInterval': GameConstants.minionSpawnInterval,
      'meleeMinionsPerWave': GameConstants.meleeMinionsPerWave,
      'rangedMinionsPerWave': GameConstants.rangedMinionsPerWave,
      'siegeWaveInterval': GameConstants.siegeWaveInterval,
      'meleeMinionHp': GameConstants.meleeMinionHp,
      'meleeMinionDamage': GameConstants.meleeMinionDamage,
      'meleeMinionSpeed': GameConstants.meleeMinionSpeed,
      'meleeMinionRange': GameConstants.meleeMinionRange,
      'rangedMinionHp': GameConstants.rangedMinionHp,
      'rangedMinionDamage': GameConstants.rangedMinionDamage,
      'rangedMinionSpeed': GameConstants.rangedMinionSpeed,
      'rangedMinionRange': GameConstants.rangedMinionRange,
      'siegeMinionHp': GameConstants.siegeMinionHp,
      'siegeMinionDamage': GameConstants.siegeMinionDamage,
      'siegeMinionSpeed': GameConstants.siegeMinionSpeed,
      'siegeMinionRange': GameConstants.siegeMinionRange,
      'minionAggroRange': GameConstants.minionAggroRange,
      'minionLeashRange': GameConstants.minionLeashRange,
      'baseGoldPerSecond': GameConstants.baseGoldPerSecond,
      'goldPerMinionKill': GameConstants.goldPerMinionKill,
      'goldPerTurretKill': GameConstants.goldPerTurretKill,
      'goldPerHeroKill': GameConstants.goldPerHeroKill,
      'respawnBaseTime': GameConstants.respawnBaseTime,
      'respawnTimePerLevel': GameConstants.respawnTimePerLevel,
    };
  }

  static void applyGameConfig(Map<String, dynamic> config) {
    if (config.containsKey('worldWidth')) GameConstants.worldWidth = (config['worldWidth'] as num).toDouble();
    if (config.containsKey('worldHeight')) GameConstants.worldHeight = (config['worldHeight'] as num).toDouble();
    if (config.containsKey('blueBaseX')) GameConstants.blueBaseX = (config['blueBaseX'] as num).toDouble();
    if (config.containsKey('blueBaseY')) GameConstants.blueBaseY = (config['blueBaseY'] as num).toDouble();
    if (config.containsKey('redBaseX')) GameConstants.redBaseX = (config['redBaseX'] as num).toDouble();
    if (config.containsKey('redBaseY')) GameConstants.redBaseY = (config['redBaseY'] as num).toDouble();
    if (config.containsKey('crystalBlueX')) GameConstants.crystalBlueX = (config['crystalBlueX'] as num).toDouble();
    if (config.containsKey('crystalBlueY')) GameConstants.crystalBlueY = (config['crystalBlueY'] as num).toDouble();
    if (config.containsKey('crystalRedX')) GameConstants.crystalRedX = (config['crystalRedX'] as num).toDouble();
    if (config.containsKey('crystalRedY')) GameConstants.crystalRedY = (config['crystalRedY'] as num).toDouble();
    if (config.containsKey('turretOuterRange')) GameConstants.turretOuterRange = (config['turretOuterRange'] as num).toDouble();
    if (config.containsKey('turretInnerRange')) GameConstants.turretInnerRange = (config['turretInnerRange'] as num).toDouble();
    if (config.containsKey('turretBaseRange')) GameConstants.turretBaseRange = (config['turretBaseRange'] as num).toDouble();
    if (config.containsKey('turretOuterHp')) GameConstants.turretOuterHp = (config['turretOuterHp'] as num).toDouble();
    if (config.containsKey('turretInnerHp')) GameConstants.turretInnerHp = (config['turretInnerHp'] as num).toDouble();
    if (config.containsKey('turretBaseHp')) GameConstants.turretBaseHp = (config['turretBaseHp'] as num).toDouble();
    if (config.containsKey('turretDamage')) GameConstants.turretDamage = (config['turretDamage'] as num).toDouble();
    if (config.containsKey('turretAttackSpeed')) GameConstants.turretAttackSpeed = (config['turretAttackSpeed'] as num).toDouble();
    if (config.containsKey('crystalHp')) GameConstants.crystalHp = (config['crystalHp'] as num).toDouble();
    if (config.containsKey('minionSpawnInterval')) GameConstants.minionSpawnInterval = (config['minionSpawnInterval'] as num).toDouble();
    if (config.containsKey('meleeMinionsPerWave')) GameConstants.meleeMinionsPerWave = (config['meleeMinionsPerWave'] as num).toInt();
    if (config.containsKey('rangedMinionsPerWave')) GameConstants.rangedMinionsPerWave = (config['rangedMinionsPerWave'] as num).toInt();
    if (config.containsKey('siegeWaveInterval')) GameConstants.siegeWaveInterval = (config['siegeWaveInterval'] as num).toInt();
    if (config.containsKey('meleeMinionHp')) GameConstants.meleeMinionHp = (config['meleeMinionHp'] as num).toDouble();
    if (config.containsKey('meleeMinionDamage')) GameConstants.meleeMinionDamage = (config['meleeMinionDamage'] as num).toDouble();
    if (config.containsKey('meleeMinionSpeed')) GameConstants.meleeMinionSpeed = (config['meleeMinionSpeed'] as num).toDouble();
    if (config.containsKey('meleeMinionRange')) GameConstants.meleeMinionRange = (config['meleeMinionRange'] as num).toDouble();
    if (config.containsKey('rangedMinionHp')) GameConstants.rangedMinionHp = (config['rangedMinionHp'] as num).toDouble();
    if (config.containsKey('rangedMinionDamage')) GameConstants.rangedMinionDamage = (config['rangedMinionDamage'] as num).toDouble();
    if (config.containsKey('rangedMinionSpeed')) GameConstants.rangedMinionSpeed = (config['rangedMinionSpeed'] as num).toDouble();
    if (config.containsKey('rangedMinionRange')) GameConstants.rangedMinionRange = (config['rangedMinionRange'] as num).toDouble();
    if (config.containsKey('siegeMinionHp')) GameConstants.siegeMinionHp = (config['siegeMinionHp'] as num).toDouble();
    if (config.containsKey('siegeMinionDamage')) GameConstants.siegeMinionDamage = (config['siegeMinionDamage'] as num).toDouble();
    if (config.containsKey('siegeMinionSpeed')) GameConstants.siegeMinionSpeed = (config['siegeMinionSpeed'] as num).toDouble();
    if (config.containsKey('siegeMinionRange')) GameConstants.siegeMinionRange = (config['siegeMinionRange'] as num).toDouble();
    if (config.containsKey('minionAggroRange')) GameConstants.minionAggroRange = (config['minionAggroRange'] as num).toDouble();
    if (config.containsKey('minionLeashRange')) GameConstants.minionLeashRange = (config['minionLeashRange'] as num).toDouble();
    if (config.containsKey('baseGoldPerSecond')) GameConstants.baseGoldPerSecond = (config['baseGoldPerSecond'] as num).toDouble();
    if (config.containsKey('goldPerMinionKill')) GameConstants.goldPerMinionKill = (config['goldPerMinionKill'] as num).toInt();
    if (config.containsKey('goldPerTurretKill')) GameConstants.goldPerTurretKill = (config['goldPerTurretKill'] as num).toInt();
    if (config.containsKey('goldPerHeroKill')) GameConstants.goldPerHeroKill = (config['goldPerHeroKill'] as num).toInt();
    if (config.containsKey('respawnBaseTime')) GameConstants.respawnBaseTime = (config['respawnBaseTime'] as num).toDouble();
    if (config.containsKey('respawnTimePerLevel')) GameConstants.respawnTimePerLevel = (config['respawnTimePerLevel'] as num).toDouble();
  }

  static Map<String, dynamic> extractHeroConfig() {
    return _sanitizeForJson(HeroDefinitions.heroes) as Map<String, dynamic>;
  }

  static void applyHeroConfig(Map<String, dynamic> config) {
    final restored = _restoreFromJson(config);
    HeroDefinitions.heroes = Map<String, Map<String, dynamic>>.from(restored);
  }

  static dynamic _sanitizeForJson(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitizeForJson(v)));
    } else if (value is List) {
      return value.map((e) => _sanitizeForJson(e)).toList();
    } else if (value is Enum) {
      return value.name;
    }
    return value;
  }

  static dynamic _restoreFromJson(dynamic value) {
    if (value is Map) {
      return value.map((k, v) {
        if (k == 'role') {
          return MapEntry(k, HeroRole.values.firstWhere((e) => e.name == v, orElse: () => HeroRole.warrior));
        } else if (k == 'type') {
          return MapEntry(k, DamageType.values.firstWhere((e) => e.name == v, orElse: () => DamageType.physical));
        }
        return MapEntry(k, _restoreFromJson(v));
      });
    } else if (value is List) {
      return value.map((e) => _restoreFromJson(e)).toList();
    }
    return value;
  }
}
