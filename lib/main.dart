import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/lobby.dart';
import 'utils/config_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ConfigManager.loadConfig();
  } catch (e) {
    // A failed config load must not prevent the game from starting;
    // defaults from GameConstants are used instead.
    debugPrint('Config load failed, using defaults: $e');
  }
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MiniMobaApp());
}

class MiniMobaApp extends StatelessWidget {
  const MiniMobaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini MOBA Arena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      home: const LobbyScreen(),
    );
  }
}
