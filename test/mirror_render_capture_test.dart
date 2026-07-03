import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:moba_z/game/moba_game.dart';
import 'package:moba_z/network/network_manager.dart';
import 'package:moba_z/network/packet_parser.dart';
import 'package:moba_z/utils/constants.dart';

Future<void> _capture(MobaGame game, String outPath) async {
  const size = ui.Size(800, 600);
  game.setViewSize(size.width, size.height);
  for (int i = 0; i < 5; i++) {
    game.update(0.016);
  }
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  game.render(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(outPath).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Map<String, dynamic> _entity(int id, String type, Team team, double x, double y, double angle) {
  return {
    'id': id, 'type': type, 'team': team.index,
    'x': x, 'y': y, 'hp': 80.0, 'maxHp': 100.0, 'angle': angle,
    'alive': true, 'atk': false,
  };
}

Map<String, dynamic> _struct(int id, int type, Team team, double x, double y) {
  return {
    'id': id, 'type': type, 'team': team.index,
    'x': x, 'y': y, 'hp': 400.0, 'maxHp': 500.0, 'alive': true,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('capture mirrored (red client) vs unmirrored (blue host) render', () async {
    // Red hero near its own crystal (2740, 460), facing toward the blue base
    // (down-left) — angle ~2.35 rad (135°) points down-left in screen coords.
    final entities = [
      _entity(1, 'warrior', Team.blue, GameConstants.blueBaseX + 60, GameConstants.blueBaseY - 60, -0.78),
      _entity(2, 'mage', Team.red, GameConstants.redBaseX - 60, GameConstants.redBaseY + 60, 2.35),
    ];
    final structs = [
      _struct(10, StructureType.crystal.index, Team.blue, GameConstants.crystalBlueX, GameConstants.crystalBlueY),
      _struct(11, StructureType.crystal.index, Team.red, GameConstants.crystalRedX, GameConstants.crystalRedY),
    ];
    final packetData = PacketParser.encodeFullState(entities, structs, 12.0);

    // Host view: blue team, unmirrored.
    final hostNetwork = NetworkManager(playerName: 'host');
    final hostGame = MobaGame(isHost: true, network: hostNetwork);
    hostGame.initializeGame([
      {'hero': 'warrior', 'team': Team.blue, 'name': 'Host'},
      {'hero': 'mage', 'team': Team.red, 'name': 'Client'},
    ]);
    // Move host's own hero to the same spot as entity id in the fake state above.
    hostGame.hostEngine!.heroes[0].position = Vector2(GameConstants.blueBaseX + 60, GameConstants.blueBaseY - 60);
    hostGame.hostEngine!.heroes[0].angle = -0.78;
    await _capture(hostGame, 'C:/Users/zimfv/AppData/Local/Temp/claude/c--Users-zimfv-OneDrive-Desktop-teachflow-moba-z/7d559af8-398f-4d75-83c7-73c3d877997c/scratchpad/host_blue_unmirrored.png');

    // Client view: red team, should be mirrored.
    final clientNetwork = NetworkManager(playerName: 'client');
    final clientGame = MobaGame(isHost: false, network: clientNetwork);
    clientGame.setLocalTeam(Team.red, 1);
    clientGame.clientEngine!.handlePacket(GamePacket(type: PacketType.fullState, data: packetData));
    expect(clientGame.isMirrored, isTrue);
    await _capture(clientGame, 'C:/Users/zimfv/AppData/Local/Temp/claude/c--Users-zimfv-OneDrive-Desktop-teachflow-moba-z/7d559af8-398f-4d75-83c7-73c3d877997c/scratchpad/client_red_mirrored.png');
  });
}
