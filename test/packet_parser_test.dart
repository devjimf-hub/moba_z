import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:moba_z/network/packet_parser.dart';
import 'package:moba_z/utils/constants.dart';

void main() {
  group('Packet round-trip: encode → decode → parse', () {
    test('position', () {
      final pos = Vector2(1234.5, 5678.9);
      final encoded = PacketParser.encodePosition(42, pos, 1.57, 0.5, -0.3);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.position, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parsePosition(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['id'], 42);
      expect(parsed['x'], closeTo(1234.5, 0.1));
      expect(parsed['y'], closeTo(5678.9, 0.1));
      expect(parsed['angle'], closeTo(1.57, 0.01));
      expect(parsed['mx'], closeTo(0.5, 0.01));
      expect(parsed['my'], closeTo(-0.3, 0.01));
    });

    test('attack', () {
      final encoded = PacketParser.encodeAttack(10, 20, 55.5);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.attack, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseAttack(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['attacker'], 10);
      expect(parsed['target'], 20);
      expect(parsed['damage'], closeTo(55.5, 0.1));
    });

    test('health', () {
      final encoded = PacketParser.encodeHealth(7, 1500.0, 2000.0);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.health, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseHealth(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['id'], 7);
      expect(parsed['hp'], closeTo(1500.0, 0.1));
      expect(parsed['maxHp'], closeTo(2000.0, 0.1));
    });

    test('skill', () {
      final target = Vector2(300.0, 400.0);
      final encoded = PacketParser.encodeSkill(5, 'skill1', target);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.skill, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseSkill(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['id'], 5);
      expect(parsed['skill'], 'skill1');
      expect(parsed['tx'], closeTo(300.0, 0.1));
      expect(parsed['ty'], closeTo(400.0, 0.1));
    });

    test('skill with null target', () {
      final encoded = PacketParser.encodeSkill(5, 'ultimate', null);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.skill, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseSkill(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['tx'], 0.0);
      expect(parsed['ty'], 0.0);
    });

    test('death', () {
      final encoded = PacketParser.encodeDeath(33, 11);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.death, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseDeath(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['id'], 33);
      expect(parsed['killer'], 11);
    });

    test('death with null killer', () {
      final encoded = PacketParser.encodeDeath(33, null);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.death, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseDeath(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['id'], 33);
      expect(parsed['killer'], -1);
    });

    test('kill', () {
      final encoded = PacketParser.encodeKill(1, 2, 300);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.kill, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseKill(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['hero'], 1);
      expect(parsed['victim'], 2);
      expect(parsed['gold'], 300);
    });

    test('minionSpawn', () {
      final pos = Vector2(500.0, 600.0);
      final encoded = PacketParser.encodeMinionSpawn(99, MinionType.ranged, Team.red, pos);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.minionSpawn, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseMinionSpawn(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['id'], 99);
      expect(parsed['type'], MinionType.ranged);
      expect(parsed['team'], Team.red);
      expect(parsed['x'], closeTo(500.0, 0.1));
      expect(parsed['y'], closeTo(600.0, 0.1));
    });

    test('structureDamage', () {
      final encoded = PacketParser.encodeStructureDamage(55, 2500.0);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.structureDamage, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseStructureDamage(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['id'], 55);
      expect(parsed['hp'], closeTo(2500.0, 0.1));
    });

    test('structureDeath', () {
      final encoded = PacketParser.encodeStructureDeath(55);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.structureDeath, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseStructureDeath(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['id'], 55);
    });

    test('gameStart', () {
      final encoded = PacketParser.encodeGameStart(123456);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.gameStart, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseGameStart(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['seed'], 123456);
    });

    test('gameOver', () {
      final encoded = PacketParser.encodeGameOver(Team.red);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.gameOver, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseGameOver(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['winner'], Team.red);
    });

    test('playerJoin', () {
      final encoded = PacketParser.encodePlayerJoin(42, 'Alice');
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.playerJoin, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parsePlayerJoin(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['peerId'], 42);
      expect(parsed['name'], 'Alice');
    });

    test('playerInput', () {
      final encoded = PacketParser.encodePlayerInput(0, 1.5, -2.3, true, [1, 3]);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.playerInput, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parsePlayerInput(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['hero'], 0);
      expect(parsed['mx'], closeTo(1.5, 0.01));
      expect(parsed['my'], closeTo(-2.3, 0.01));
      expect(parsed['attacking'], true);
      expect(parsed['skills'], [1, 3]);
    });

    test('playerInput with empty skills', () {
      final encoded = PacketParser.encodePlayerInput(1, 0.0, 0.0, false, []);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.playerInput, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parsePlayerInput(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['skills'], isEmpty);
    });

    test('fullState', () {
      final entities = [
        {
          'id': 1, 'type': 'warrior', 'team': 0,
          'x': 100.0, 'y': 200.0,
          'hp': 2000.0, 'maxHp': 2200.0,
          'angle': 0.5, 'alive': true, 'atk': false,
        },
        {
          'id': 2, 'type': 'minion_0', 'team': 1,
          'x': 500.0, 'y': 600.0,
          'hp': 400.0, 'maxHp': 600.0,
          'angle': 1.0, 'alive': true, 'atk': true,
        },
      ];
      final structures = [
        {
          'id': 10, 'type': 0, 'team': 0,
          'x': 300.0, 'y': 400.0,
          'hp': 2500.0, 'maxHp': 3000.0,
          'alive': true,
        },
      ];
      final encoded = PacketParser.encodeFullState(entities, structures, 45.5);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.fullState, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseFullState(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['gameTime'], closeTo(45.5, 0.1));
      final eList = parsed['entities'] as List;
      expect(eList.length, 2);
      expect(eList[0]['id'], 1);
      expect(eList[0]['type'], 'warrior');
      expect(eList[1]['atk'], true);
      final sList = parsed['structures'] as List;
      expect(sList.length, 1);
      expect(sList[0]['id'], 10);
    });

    test('heroSelect', () {
      final encoded = PacketParser.encodeHeroSelect(2, Team.blue, 'Player1');
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.heroSelect, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseHeroSelect(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['heroIndex'], 2);
      expect(parsed['team'], Team.blue);
      expect(parsed['name'], 'Player1');
    });

    test('gold', () {
      final encoded = PacketParser.encodeGold(7, 1500);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.gold, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseGold(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['id'], 7);
      expect(parsed['gold'], 1500);
    });

    test('respawn', () {
      final encoded = PacketParser.encodeRespawn(33, 7.5);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.respawn, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parseRespawn(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['id'], 33);
      expect(parsed['time'], closeTo(7.5, 0.1));
    });

    test('ping', () {
      final encoded = PacketParser.encodePing(42);
      final packet = PacketParser.decode(PacketParser.encode(
        GamePacket(type: PacketType.ping, data: encoded),
      ));
      expect(packet, isNotNull);
      final parsed = PacketParser.parsePing(packet!.data);
      expect(parsed, isNotNull);
      expect(parsed!['seq'], 42);
      expect(parsed['sent'], isA<int>());
      expect(parsed['received'], isA<int>());
    });
  });

  group('PacketParser.decode edge cases', () {
    test('returns null for empty string', () {
      expect(PacketParser.decode(''), isNull);
    });

    test('returns null for no colon', () {
      expect(PacketParser.decode('invalid'), isNull);
    });

    test('returns null for invalid type index', () {
      expect(PacketParser.decode('999:data'), isNull);
    });

    test('handles valid packet correctly', () {
      final packet = PacketParser.decode('2:H:1:100.0:200.0');
      expect(packet, isNotNull);
      expect(packet!.type, PacketType.health);
      expect(packet.data, 'H:1:100.0:200.0');
    });
  });
}
