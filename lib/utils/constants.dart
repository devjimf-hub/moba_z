import 'dart:ui';

class GameConstants {
  GameConstants._();

  static double worldWidth = 3200.0;
  static double worldHeight = 3200.0;

  static const double tileWidth = 48.0;
  static const double tileHeight = 48.0;

  static const int tilesX = 67;
  static const int tilesY = 67;

  static const double laneWidth = 144.0;
  static const double riverWidth = 200.0;

  // Diagonal MOBA layout: Blue bottom-left, Red top-right
  static double blueBaseX = 400.0;
  static double blueBaseY = 2800.0;
  static double redBaseX = 2800.0;
  static double redBaseY = 400.0;

  static double crystalBlueX = 400.0;
  static double crystalBlueY = 2800.0;
  static double crystalRedX = 2800.0;
  static double crystalRedY = 400.0;

  static double turretOuterRange = 500.0;
  static double turretInnerRange = 400.0;
  static double turretBaseRange = 350.0;

  static double turretOuterHp = 3000.0;
  static double turretInnerHp = 4000.0;
  static double turretBaseHp = 5000.0;

  static double turretDamage = 120.0;
  static double turretAttackSpeed = 1.0;

  static double crystalHp = 8000.0;

  static double minionSpawnInterval = 20.0;
  static int meleeMinionsPerWave = 3;
  static int rangedMinionsPerWave = 2;
  static int siegeWaveInterval = 3;

  static double meleeMinionHp = 600.0;
  static double meleeMinionDamage = 30.0;
  static double meleeMinionSpeed = 120.0;
  static double meleeMinionRange = 60.0;

  static double rangedMinionHp = 400.0;
  static double rangedMinionDamage = 50.0;
  static double rangedMinionSpeed = 110.0;
  static double rangedMinionRange = 250.0;

  static double siegeMinionHp = 1000.0;
  static double siegeMinionDamage = 80.0;
  static double siegeMinionSpeed = 90.0;
  static double siegeMinionRange = 300.0;

  static double minionAggroRange = 300.0;
  static double minionLeashRange = 600.0;

  static double baseGoldPerSecond = 2.0;
  static int goldPerMinionKill = 40;
  static int goldPerTurretKill = 250;
  static int goldPerHeroKill = 300;

  static double respawnBaseTime = 5.0;
  static double respawnTimePerLevel = 2.0;

  static const double cameraZoomMin = 0.5;
  static const double cameraZoomMax = 1.5;
  static const double cameraZoomDefault = 1.0;
  static const double cameraSmoothing = 8.0;

  static const double healthBarWidth = 48.0;
  static const double healthBarHeight = 6.0;
  static const double healthBarOffset = -30.0;

  static const double minimapWidth = 180.0;
  static const double minimapHeight = 180.0;
  static const double minimapPadding = 10.0;

  static const double hudButtonSize = 56.0;
  static const double hudButtonPadding = 12.0;

  static const double projectileSpeed = 600.0;

  static const Duration tickRate = Duration(milliseconds: 50);
  static const int networkTickRate = 20;

  static const double aiTargetSwitchCooldown = 1.0;
  static const double aiPathRecalcCooldown = 0.5;
}

enum Team { blue, red }

enum HeroRole { warrior, mage, assassin, marksman, support, tank }

enum ProjectileType { basicAttack, skill, turret, minion }

enum StructureType { outerTurret, innerTurret, baseTurret, crystal }

enum MinionType { melee, ranged, siege }

enum GameState { lobby, loading, playing, paused, victory, defeat }

enum SkillSlot { passive, skill1, skill2, ultimate }

enum DamageType { physical, magical, trueDamage }

class TeamColors {
  static const Color blueTeam = Color(0xFF2196F3);
  static const Color blueTeamDark = Color(0xFF1565C0);
  static const Color blueTeamLight = Color(0xFF64B5F6);

  static const Color redTeam = Color(0xFFF44336);
  static const Color redTeamDark = Color(0xFFC62828);
  static const Color redTeamLight = Color(0xFFEF5350);

  static const Color healthGreen = Color(0xFF4CAF50);
  static const Color healthRed = Color(0xFFF44336);
  static const Color healthYellow = Color(0xFFFFEB3B);

  static const Color manaBlue = Color(0xFF2196F3);
  static const Color gold = Color(0xFFFFD700);
  static const Color xpPurple = Color(0xFF9C27B0);

  static const Color grassGreen = Color(0xFF388E3C);
  static const Color grassLightGreen = Color(0xFF66BB6A);
  static const Color riverBlue = Color(0xFF1E88E5);
  static const Color riverLightBlue = Color(0xFF42A5F5);

  static const Color groundBrown = Color(0xFF5D4037);
  static const Color groundLightBrown = Color(0xFF795548);
  static const Color stoneGray = Color(0xFF757575);
  static const Color stoneLightGray = Color(0xFF9E9E9E);

  static const Color treeGreen = Color(0xFF2E7D32);
  static const Color treeDarkGreen = Color(0xFF1B5E20);
  static const Color treeBrown = Color(0xFF4E342E);

  static const Color waterBlue = Color(0xFF1565C0);
  static const Color waterLightBlue = Color(0xFF1E88E5);
  static const Color waterFoam = Color(0xFF90CAF9);
}

class HeroDefinitions {
  HeroDefinitions._();

  static Map<String, Map<String, dynamic>> heroes = {
    'warrior': {
      'name': 'Blade Knight',
      'role': HeroRole.warrior,
      'hp': 2200,
      'mana': 800,
      'moveSpeed': 180,
      'attackSpeed': 0.8,
      'attackRange': 80,
      'armor': 45,
      'magicResist': 30,
      'critChance': 0.1,
      'baseDamage': 110,
      'skills': {
        'skill1': {
          'name': 'Slash',
          'damage': 150,
          'cooldown': 5.0,
          'range': 120,
          'type': DamageType.physical,
          'description': 'A powerful forward slash',
        },
        'skill2': {
          'name': 'Shield Bash',
          'damage': 100,
          'cooldown': 8.0,
          'range': 100,
          'type': DamageType.physical,
          'description': 'Stuns nearby enemies briefly',
        },
        'ultimate': {
          'name': 'Blade Storm',
          'damage': 400,
          'cooldown': 40.0,
          'range': 200,
          'type': DamageType.physical,
          'description': 'Spinning blade attack hitting all nearby enemies',
        },
        'passive': {
          'name': 'Battle Fury',
          'description': 'Gains attack speed after each hit',
        },
      },
    },
    'mage': {
      'name': 'Arcane Sorcerer',
      'role': HeroRole.mage,
      'hp': 1600,
      'mana': 1200,
      'moveSpeed': 160,
      'attackSpeed': 0.6,
      'attackRange': 300,
      'armor': 20,
      'magicResist': 40,
      'critChance': 0.0,
      'baseDamage': 85,
      'skills': {
        'skill1': {
          'name': 'Fireball',
          'damage': 200,
          'cooldown': 4.0,
          'range': 400,
          'type': DamageType.magical,
          'description': 'Launches an explosive fireball',
        },
        'skill2': {
          'name': 'Frost Nova',
          'damage': 150,
          'cooldown': 7.0,
          'range': 250,
          'type': DamageType.magical,
          'description': 'Freezes and damages nearby enemies',
        },
        'ultimate': {
          'name': 'Meteor Strike',
          'damage': 600,
          'cooldown': 45.0,
          'range': 500,
          'type': DamageType.magical,
          'description': 'Calls down a devastating meteor',
        },
        'passive': {
          'name': 'Mana Surge',
          'description': 'Regenerates mana faster when low',
        },
      },
    },
    'assassin': {
      'name': 'Shadow Blade',
      'role': HeroRole.assassin,
      'hp': 1800,
      'mana': 900,
      'moveSpeed': 210,
      'attackSpeed': 1.1,
      'attackRange': 70,
      'armor': 30,
      'magicResist': 25,
      'critChance': 0.25,
      'baseDamage': 130,
      'skills': {
        'skill1': {
          'name': 'Backstab',
          'damage': 250,
          'cooldown': 6.0,
          'range': 90,
          'type': DamageType.physical,
          'description': 'Teleports behind target dealing massive damage',
        },
        'skill2': {
          'name': 'Smoke Bomb',
          'damage': 80,
          'cooldown': 10.0,
          'range': 150,
          'type': DamageType.magical,
          'description': 'Becomes invisible briefly and slows enemies',
        },
        'ultimate': {
          'name': 'Shadow Dance',
          'damage': 500,
          'cooldown': 35.0,
          'range': 120,
          'type': DamageType.physical,
          'description': 'Dashes through enemies dealing critical damage',
        },
        'passive': {
          'name': 'Lethality',
          'description': 'Critical hits deal bonus damage to low HP targets',
        },
      },
    },
    'marksman': {
      'name': 'Ranger',
      'role': HeroRole.marksman,
      'hp': 1500,
      'mana': 850,
      'moveSpeed': 170,
      'attackSpeed': 1.2,
      'attackRange': 350,
      'armor': 20,
      'magicResist': 20,
      'critChance': 0.2,
      'baseDamage': 100,
      'skills': {
        'skill1': {
          'name': 'Piercing Arrow',
          'damage': 180,
          'cooldown': 5.0,
          'range': 500,
          'type': DamageType.physical,
          'description': 'Fires a long range arrow through enemies',
        },
        'skill2': {
          'name': 'Roll',
          'damage': 0,
          'cooldown': 8.0,
          'range': 0,
          'type': DamageType.physical,
          'description': 'Quick dodge roll for repositioning',
        },
        'ultimate': {
          'name': 'Rain of Arrows',
          'damage': 350,
          'cooldown': 40.0,
          'range': 450,
          'type': DamageType.physical,
          'description': 'Launches volley of arrows in a large area',
        },
        'passive': {
          'name': 'Sharp Eye',
          'description': 'Each consecutive hit increases crit chance',
        },
      },
    },
    'support': {
      'name': 'Light Weaver',
      'role': HeroRole.support,
      'hp': 1800,
      'mana': 1100,
      'moveSpeed': 165,
      'attackSpeed': 0.7,
      'attackRange': 250,
      'armor': 30,
      'magicResist': 45,
      'critChance': 0.0,
      'baseDamage': 70,
      'skills': {
        'skill1': {
          'name': 'Healing Light',
          'damage': -200,
          'cooldown': 6.0,
          'range': 300,
          'type': DamageType.magical,
          'description': 'Heals the nearest ally',
        },
        'skill2': {
          'name': 'Divine Shield',
          'damage': 0,
          'cooldown': 12.0,
          'range': 250,
          'type': DamageType.magical,
          'description': 'Grants temporary shield to ally',
        },
        'ultimate': {
          'name': 'Resurrection Aura',
          'damage': 0,
          'cooldown': 60.0,
          'range': 350,
          'type': DamageType.magical,
          'description': 'Boosts nearby allies stats significantly',
        },
        'passive': {
          'name': 'Blessing',
          'description': 'Nearby allies gain passive HP regen',
        },
      },
    },
    'tank': {
      'name': 'Iron Golem',
      'role': HeroRole.tank,
      'hp': 3000,
      'mana': 600,
      'moveSpeed': 150,
      'attackSpeed': 0.6,
      'attackRange': 80,
      'armor': 60,
      'magicResist': 40,
      'critChance': 0.0,
      'baseDamage': 90,
      'skills': {
        'skill1': {
          'name': 'Ground Slam',
          'damage': 120,
          'cooldown': 6.0,
          'range': 150,
          'type': DamageType.physical,
          'description': 'Slams the ground slowing enemies',
        },
        'skill2': {
          'name': 'Taunt',
          'damage': 0,
          'cooldown': 10.0,
          'range': 200,
          'type': DamageType.physical,
          'description': 'Forces nearby enemies to attack you',
        },
        'ultimate': {
          'name': 'Seismic Charge',
          'damage': 300,
          'cooldown': 42.0,
          'range': 300,
          'type': DamageType.physical,
          'description': 'Charges forward knocking up enemies',
        },
        'passive': {
          'name': 'Fortitude',
          'description': 'Gains bonus armor when taking damage',
        },
      },
    },
  };
}
