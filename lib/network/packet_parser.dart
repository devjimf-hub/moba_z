import 'package:vector_math/vector_math_64.dart';
import '../utils/constants.dart';

enum PacketType {
  position,
  attack,
  health,
  skill,
  death,
  kill,
  minionSpawn,
  structureDamage,
  structureDeath,
  gameStart,
  gameOver,
  playerJoin,
  playerReady,
  playerInput,
  fullState,
  heroSelect,
  gold,
  respawn,
  ping,
}

class GamePacket {
  final PacketType type;
  final String data;
  final int timestamp;

  GamePacket({required this.type, required this.data, int? timestamp})
      : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  @override
  String toString() => '${type.name}:$data';
}

class PacketParser {
  PacketParser._();

  static String encode(GamePacket packet) {
    return '${packet.type.index}:${packet.data}';
  }

  static GamePacket? decode(String raw) {
    final colonIdx = raw.indexOf(':');
    if (colonIdx < 0) return null;
    try {
      final typeIdx = int.parse(raw.substring(0, colonIdx));
      final type = PacketType.values[typeIdx];
      final data = raw.substring(colonIdx + 1);
      return GamePacket(type: type, data: data);
    } catch (_) {
      return null;
    }
  }

  static String encodePosition(int entityId, Vector2 pos, double angle, double moveX, double moveY) {
    return 'P:$entityId:${pos.x.toStringAsFixed(1)}:${pos.y.toStringAsFixed(1)}:${angle.toStringAsFixed(2)}:${moveX.toStringAsFixed(2)}:${moveY.toStringAsFixed(2)}';
  }

  static Map<String, dynamic>? parsePosition(String data) {
    final stripped = data.replaceFirst('P:', '');
    final parts = stripped.split(':');
    if (parts.length < 4) return null;
    return {
      'id': int.parse(parts[0]),
      'x': double.parse(parts[1]),
      'y': double.parse(parts[2]),
      'angle': double.parse(parts[3]),
      'mx': parts.length > 4 ? double.parse(parts[4]) : 0.0,
      'my': parts.length > 5 ? double.parse(parts[5]) : 0.0,
    };
  }

  static String encodeAttack(int attackerId, int targetId, double damage) {
    return 'A:$attackerId:$targetId:${damage.toStringAsFixed(1)}';
  }

  static Map<String, dynamic>? parseAttack(String data) {
    final stripped = data.replaceFirst('A:', '');
    final parts = stripped.split(':');
    if (parts.length < 3) return null;
    return {
      'attacker': int.parse(parts[0]),
      'target': int.parse(parts[1]),
      'damage': double.parse(parts[2]),
    };
  }

  static String encodeHealth(int entityId, double hp, double maxHp) {
    return 'H:$entityId:${hp.toStringAsFixed(1)}:${maxHp.toStringAsFixed(1)}';
  }

  static Map<String, dynamic>? parseHealth(String data) {
    final stripped = data.replaceFirst('H:', '');
    final parts = stripped.split(':');
    if (parts.length < 3) return null;
    return {
      'id': int.parse(parts[0]),
      'hp': double.parse(parts[1]),
      'maxHp': double.parse(parts[2]),
    };
  }

  static String encodeSkill(int entityId, String skillName, Vector2? target) {
    final tx = target != null ? target.x.toStringAsFixed(1) : '0';
    final ty = target != null ? target.y.toStringAsFixed(1) : '0';
    return 'S:$entityId:$skillName:$tx:$ty';
  }

  static Map<String, dynamic>? parseSkill(String data) {
    final stripped = data.replaceFirst('S:', '');
    final parts = stripped.split(':');
    if (parts.length < 2) return null;
    return {
      'id': int.parse(parts[0]),
      'skill': parts[1],
      'tx': parts.length > 2 ? double.parse(parts[2]) : 0.0,
      'ty': parts.length > 3 ? double.parse(parts[3]) : 0.0,
    };
  }

  static String encodeDeath(int entityId, int? killerId) {
    return 'D:$entityId:${killerId ?? -1}';
  }

  static Map<String, dynamic>? parseDeath(String data) {
    final stripped = data.replaceFirst('D:', '');
    final parts = stripped.split(':');
    if (parts.length < 1) return null;
    return {
      'id': int.parse(parts[0]),
      'killer': parts.length > 1 ? int.parse(parts[1]) : -1,
    };
  }

  static String encodeKill(int heroId, int victimId, int gold) {
    return 'K:$heroId:$victimId:$gold';
  }

  static Map<String, dynamic>? parseKill(String data) {
    final stripped = data.replaceFirst('K:', '');
    final parts = stripped.split(':');
    if (parts.length < 3) return null;
    return {
      'hero': int.parse(parts[0]),
      'victim': int.parse(parts[1]),
      'gold': int.parse(parts[2]),
    };
  }

  static String encodeMinionSpawn(int minionId, MinionType type, Team team, Vector2 pos) {
    return 'MS:$minionId:${type.index}:${team.index}:${pos.x.toStringAsFixed(1)}:${pos.y.toStringAsFixed(1)}';
  }

  static Map<String, dynamic>? parseMinionSpawn(String data) {
    final stripped = data.replaceFirst('MS:', '');
    final parts = stripped.split(':');
    if (parts.length < 5) return null;
    return {
      'id': int.parse(parts[0]),
      'type': MinionType.values[int.parse(parts[1])],
      'team': Team.values[int.parse(parts[2])],
      'x': double.parse(parts[3]),
      'y': double.parse(parts[4]),
    };
  }

  static String encodeStructureDamage(int structureId, double hp) {
    return 'SD:$structureId:${hp.toStringAsFixed(1)}';
  }

  static Map<String, dynamic>? parseStructureDamage(String data) {
    final stripped = data.replaceFirst('SD:', '');
    final parts = stripped.split(':');
    if (parts.length < 2) return null;
    return {
      'id': int.parse(parts[0]),
      'hp': double.parse(parts[1]),
    };
  }

  static String encodeStructureDeath(int structureId) {
    return 'SX:$structureId';
  }

  static Map<String, dynamic>? parseStructureDeath(String data) {
    final stripped = data.replaceFirst('SX:', '');
    if (stripped.isEmpty) return null;
    return {'id': int.parse(stripped)};
  }

  static String encodeGameStart(int seed) {
    return 'GS:$seed';
  }

  static Map<String, dynamic>? parseGameStart(String data) {
    final stripped = data.replaceFirst('GS:', '');
    if (stripped.isEmpty) return null;
    return {'seed': int.parse(stripped)};
  }

  static String encodeGameOver(Team winner) {
    return 'GW:${winner.index}';
  }

  static Map<String, dynamic>? parseGameOver(String data) {
    final stripped = data.replaceFirst('GW:', '');
    if (stripped.isEmpty) return null;
    return {'winner': Team.values[int.parse(stripped)]};
  }

  static String encodePlayerJoin(int peerId, String name) {
    return 'PJ:$peerId:$name';
  }

  static Map<String, dynamic>? parsePlayerJoin(String data) {
    final stripped = data.replaceFirst('PJ:', '');
    final parts = stripped.split(':');
    if (parts.length < 2) return null;
    return {
      'peerId': int.parse(parts[0]),
      'name': parts.sublist(1).join(':'),
    };
  }

  static String encodePlayerInput(int heroIndex, double mx, double my, bool attacking, List<int> skills) {
    final skillStr = skills.join(',');
    return 'PI:$heroIndex:${mx.toStringAsFixed(2)}:${my.toStringAsFixed(2)}:${attacking ? 1 : 0}:$skillStr';
  }

  static Map<String, dynamic>? parsePlayerInput(String data) {
    final stripped = data.replaceFirst('PI:', '');
    final parts = stripped.split(':');
    if (parts.length < 5) return null;
    return {
      'hero': int.parse(parts[0]),
      'mx': double.parse(parts[1]),
      'my': double.parse(parts[2]),
      'attacking': parts[3] == '1',
      'skills': parts[4].split(',').where((s) => s.isNotEmpty).map(int.parse).toList(),
    };
  }

  static String encodeFullState(List<Map<String, dynamic>> entities, List<Map<String, dynamic>> structures, double gameTime) {
    final sb = StringBuffer();
    sb.write('FS:${gameTime.toStringAsFixed(1)}');
    for (final e in entities) {
      sb.write('|E:${e['id']}:${e['type']}:${e['team']}:${e['x'].toStringAsFixed(1)}:${e['y'].toStringAsFixed(1)}:${e['hp'].toStringAsFixed(1)}:${e['maxHp'].toStringAsFixed(1)}:${e['angle'].toStringAsFixed(2)}:${e['alive'] == true ? 1 : 0}:${e['atk'] == true ? 1 : 0}');
    }
    for (final s in structures) {
      sb.write('|T:${s['id']}:${s['type']}:${s['team']}:${s['x'].toStringAsFixed(1)}:${s['y'].toStringAsFixed(1)}:${s['hp'].toStringAsFixed(1)}:${s['maxHp'].toStringAsFixed(1)}:${s['alive'] == true ? 1 : 0}');
    }
    return sb.toString();
  }

  static Map<String, dynamic>? parseFullState(String data) {
    final parts = data.split('|');
    if (parts.isEmpty) return null;
    final gameTime = double.tryParse(parts[0].replaceFirst('FS:', '')) ?? 0;
    final entities = <Map<String, dynamic>>[];
    final structures = <Map<String, dynamic>>[];
    for (int i = 1; i < parts.length; i++) {
      final p = parts[i].split(':');
      if (p.length < 2) continue;
      if (p[0] == 'E') {
        entities.add({
          'id': int.parse(p[1]),
          'type': p[2],
          'team': int.parse(p[3]),
          'x': double.parse(p[4]),
          'y': double.parse(p[5]),
          'hp': double.parse(p[6]),
          'maxHp': double.parse(p[7]),
          'angle': double.parse(p[8]),
          'alive': p[9] == '1',
          'atk': p.length > 10 ? p[10] == '1' : false,
        });
      } else if (p[0] == 'T') {
        structures.add({
          'id': int.parse(p[1]),
          'type': int.parse(p[2]),
          'team': int.parse(p[3]),
          'x': double.parse(p[4]),
          'y': double.parse(p[5]),
          'hp': double.parse(p[6]),
          'maxHp': double.parse(p[7]),
          'alive': p[8] == '1',
        });
      }
    }
    return {
      'gameTime': gameTime,
      'entities': entities,
      'structures': structures,
    };
  }

  static String encodeHeroSelect(int heroIndex, Team team, String name) {
    return 'HS:$heroIndex:${team.index}:$name';
  }

  static Map<String, dynamic>? parseHeroSelect(String data) {
    final stripped = data.replaceFirst('HS:', '');
    final parts = stripped.split(':');
    if (parts.length < 2) return null;
    return {
      'heroIndex': int.parse(parts[0]),
      'team': Team.values[int.parse(parts[1])],
      'name': parts.length > 2 ? parts.sublist(2).join(':') : '',
    };
  }

  static String encodeGold(int entityId, int gold) {
    return 'G:$entityId:$gold';
  }

  static Map<String, dynamic>? parseGold(String data) {
    final stripped = data.replaceFirst('G:', '');
    final parts = stripped.split(':');
    if (parts.length < 2) return null;
    return {
      'id': int.parse(parts[0]),
      'gold': int.parse(parts[1]),
    };
  }

  static String encodeRespawn(int entityId, double respawnTime) {
    return 'RS:$entityId:${respawnTime.toStringAsFixed(1)}';
  }

  static Map<String, dynamic>? parseRespawn(String data) {
    final stripped = data.replaceFirst('RS:', '');
    final parts = stripped.split(':');
    if (parts.length < 2) return null;
    return {
      'id': int.parse(parts[0]),
      'time': double.parse(parts[1]),
    };
  }

  static String encodePing(int sequenceNum) {
    return 'PG:$sequenceNum:${DateTime.now().millisecondsSinceEpoch}';
  }

  static Map<String, dynamic>? parsePing(String data) {
    final stripped = data.replaceFirst('PG:', '');
    final parts = stripped.split(':');
    if (parts.length < 2) return null;
    return {
      'seq': int.parse(parts[0]),
      'sent': int.parse(parts[1]),
      'received': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
