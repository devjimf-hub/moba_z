import 'package:flutter/material.dart';

class GameHud extends StatelessWidget {
  final double health;
  final double maxHealth;
  final double mana;
  final double maxMana;
  final int gold;
  final int kills;
  final int deaths;
  final double ping;
  final double fps;
  final double networkQuality;
  final double gameTime;
  final bool isHost;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const GameHud({
    super.key,
    required this.health,
    required this.maxHealth,
    required this.mana,
    required this.maxMana,
    required this.gold,
    required this.kills,
    required this.deaths,
    required this.ping,
    required this.fps,
    required this.networkQuality,
    required this.gameTime,
    required this.isHost,
    this.onSettingsPressed,
    this.onZoomIn,
    this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          _buildTopBar(context),
          _buildBottomStats(context),
          _buildZoomControls(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final minutes = (gameTime / 60).toInt();
    final seconds = (gameTime % 60).toInt();
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha:  0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha:  0.1), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha:  0.5), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 20, color: Colors.white.withValues(alpha:  0.2)),
                const SizedBox(width: 16),
                Text(
                  '$kills vs $deaths',
                  style: const TextStyle(color: Color(0xFFFFC107), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 20, color: Colors.white.withValues(alpha:  0.2)),
                const SizedBox(width: 16),
                _buildPingIndicator(),
                const SizedBox(width: 12),
                _buildFpsIndicator(),
                if (isHost) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFFD700).withValues(alpha:  0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('HOST', style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ] else ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF2196F3).withValues(alpha:  0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('CLIENT', style: TextStyle(color: Color(0xFF2196F3), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onSettingsPressed,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha:  0.75),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha:  0.1), width: 1),
              ),
              child: Icon(Icons.settings, color: Colors.white.withValues(alpha:  0.8), size: 20),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPingIndicator() {
    Color pingColor;
    if (ping < 50) {
      pingColor = const Color(0xFF4CAF50);
    } else if (ping < 100) {
      pingColor = const Color(0xFFFFEB3B);
    } else {
      pingColor = const Color(0xFFF44336);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.signal_cellular_alt, color: pingColor, size: 14),
        const SizedBox(width: 4),
        Text(
          '${ping.toInt()}ms',
          style: TextStyle(
            color: Colors.white.withValues(alpha:  0.8),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildFpsIndicator() {
    final fpsColor = fps >= 55 ? const Color(0xFF4CAF50) : fps >= 30 ? const Color(0xFFFFEB3B) : const Color(0xFFF44336);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 12,
          decoration: BoxDecoration(
            color: fpsColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${fps.toInt()} FPS',
          style: TextStyle(
            color: Colors.white.withValues(alpha:  0.7),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildBottomStats(BuildContext context) {
    final hpPercent = maxHealth > 0 ? (health / maxHealth).clamp(0.0, 1.0) : 0.0;
    final manaPercent = maxMana > 0 ? (mana / maxMana).clamp(0.0, 1.0) : 0.0;
    final double barWidth = (MediaQuery.of(context).size.width * 0.35).clamp(150.0, 300.0);

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha:  0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha:  0.1), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha:  0.5), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildLargeResourceBar(hpPercent, const Color(0xFF4CAF50), '${health.toInt()}/${maxHealth.toInt()}', barWidth),
                  const SizedBox(height: 8),
                  _buildLargeResourceBar(manaPercent, const Color(0xFF2196F3), '${mana.toInt()}/${maxMana.toInt()}', barWidth),
                ],
              ),
              const SizedBox(width: 24),
              Container(width: 2, height: 40, color: Colors.white.withValues(alpha:  0.2)),
              const SizedBox(width: 24),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatItem(Icons.monetization_on, gold.toString(), const Color(0xFFFFD700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatItem(Icons.gps_fixed, kills.toString(), const Color(0xFF4CAF50)),
                      const SizedBox(width: 12),
                      _buildStatItem(Icons.close, deaths.toString(), const Color(0xFFF44336)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeResourceBar(double percent, Color color, String text, double width) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: width,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha:  0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withValues(alpha:  0.8), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(color: color),
            ),
          ),
        ),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, shadows: [
            Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
          ]),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildZoomControls(BuildContext context) {
    return Positioned(
      top: 50,
      right: 8,
      child: Column(
        children: [
          _buildZoomButton(Icons.add, onZoomIn),
          const SizedBox(height: 4),
          _buildZoomButton(Icons.remove, onZoomOut),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback? onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha:  0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha:  0.7), size: 18),
      ),
    );
  }
}
