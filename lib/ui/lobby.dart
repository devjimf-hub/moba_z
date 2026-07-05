import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../network/network_manager.dart';
import '../network/packet_parser.dart';
import '../game/moba_game.dart';
import 'joystick.dart';
import 'skill_buttons.dart';
import 'hud.dart';
import 'admin_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with SingleTickerProviderStateMixin {
  bool _isHost = false;
  bool _isConnecting = false;
  bool _isReady = false;
  bool _opponentReady = false;
  bool _opponentJoined = false;
  bool _gameStarted = false;
  String _peerId = '';
  String _hostIdInput = '';
  String _statusMessage = 'Select Host or Join';
  NetworkManager? _network;
  MobaGame? _game;
  late AnimationController _pulseController;
  int _selectedHero = 0;
  int _opponentHeroIndex = -1;
  String _playerName = 'Player';
  String _clientPeerId = '';

  static const List<String> _heroKeys = [
    'warrior', 'mage', 'assassin', 'marksman', 'support', 'tank'
  ];
  static const List<String> _heroNames = [
    'Blade Knight', 'Arcane Sorcerer', 'Shadow Blade',
    'Ranger', 'Light Weaver', 'Iron Golem'
  ];
  static const List<String> _heroRoles = [
    'Warrior', 'Mage', 'Assassin', 'Marksman', 'Support', 'Tank'
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _network?.dispose();
    super.dispose();
  }

  void _createHost() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Creating host...';
    });

    _network = NetworkManager(
      playerName: _playerName,
      onConnectionChanged: (connected) {
        if (connected && mounted && _network != null) {
          setState(() {
            if (_network!.connectionCount > 0) {
              _opponentJoined = true;
              final peerIds = _network!.connectedPeerIds;
              if (peerIds.isNotEmpty) {
                _clientPeerId = peerIds.first;
              }
              _statusMessage = 'Opponent joined! Select your hero.';
            } else {
              _statusMessage = 'Waiting for opponent...';
            }
          });
          _checkStartGame();
        }
      },
    );

    _network!.onPacketReceived = (packet) {
      if (packet.type == PacketType.playerJoin) {
        _handleOpponentJoined(packet.data);
      } else if (packet.type == PacketType.heroSelect) {
        _handleOpponentHeroSelect(packet.data);
      }
    };

    await _network!.initHost();
    _peerId = _network!.peerId;

    setState(() {
      _isHost = true;
      _isConnecting = false;
      _statusMessage = 'Host ready. Share your ID with opponent.';
    });
  }

  void _joinHost() async {
    if (_hostIdInput.trim().isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a Host Peer ID';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to host...';
    });

    _network = NetworkManager(
      playerName: _playerName,
      onConnectionChanged: (connected) {
        if (connected && mounted) {
          setState(() {
            _statusMessage = 'Connected! Select your hero.';
          });
        } else if (!connected && mounted) {
          setState(() {
            _statusMessage = 'Connection lost.';
            _isConnecting = false;
          });
        }
      },
    );

    _network!.onPacketReceived = (packet) {
      if (packet.type == PacketType.gameStart) {
        _handleGameStart(packet.data);
      }
    };

    await _network!.initClient(_hostIdInput.trim());
    _peerId = _network!.peerId;

    setState(() {
      _isHost = false;
      _isConnecting = false;
      _statusMessage = 'Connected! Select your hero.';
    });
  }

  void _selectHero(int index) {
    setState(() {
      _selectedHero = index;
    });
  }

  void _readyUp() {
    if (_network == null) return;
    setState(() {
      _isReady = true;
      _statusMessage = 'Waiting for other player...';
    });

    if (_isHost) {
      _network!.sendPacket(GamePacket(
        type: PacketType.heroSelect,
        data: PacketParser.encodeHeroSelect(_selectedHero, Team.blue, _playerName),
      ));
      _checkStartGame();
    } else {
      _network!.sendToHost(GamePacket(
        type: PacketType.heroSelect,
        data: PacketParser.encodeHeroSelect(_selectedHero, Team.red, _playerName),
      ));
    }
  }

  void _handleOpponentJoined(String data) {
    final parts = data.split(':');
    if (parts.length < 2) return;
    _clientPeerId = parts[0];
    _opponentJoined = true;
    setState(() {
      _statusMessage = 'Opponent joined! Select your hero.';
    });
    _checkStartGame();
  }

  void _handleOpponentHeroSelect(String data) {
    final parsed = PacketParser.parseHeroSelect(data);
    if (parsed != null) {
      _opponentHeroIndex = parsed['heroIndex'] as int;
    } else {
      final parts = data.split(':');
      if (parts.length >= 2) {
        _opponentHeroIndex = int.tryParse(parts[1]) ?? -1;
      }
    }
    _opponentReady = true;
    setState(() {
      _statusMessage = 'Opponent ready! Waiting for you...';
    });
    _checkStartGame();
  }

  void _checkStartGame() {
    if (_gameStarted) return;
    if (!_isReady || !_opponentReady) return;
    if (_isHost && !_opponentJoined) return;
    _startGame();
  }

  void _handleGameStart(String data) {
    _startGame();
  }

  void _startGame() {
    if (_gameStarted || _network == null) return;
    _gameStarted = true;

    final game = MobaGame(isHost: _isHost, network: _network!);

    if (_isHost) {
      final oppIdx = _opponentHeroIndex >= 0 ? _opponentHeroIndex : ((_selectedHero + 1) % _heroKeys.length);
      final selections = [
        {'hero': _heroKeys[_selectedHero], 'team': Team.blue, 'name': _playerName},
        {'hero': _heroKeys[oppIdx], 'team': Team.red, 'name': 'Opponent'},
      ];
      game.initializeGame(selections, clientPeerId: _clientPeerId.isNotEmpty ? _clientPeerId : null);
    } else {
      game.setLocalTeam(Team.red, 1);
    }

    setState(() {
      _game = game;
    });
  }

  void _copyPeerId() {
    Clipboard.setData(ClipboardData(text: _peerId));
    setState(() {
      _statusMessage = 'Peer ID copied to clipboard!';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_game != null) {
      return GameWidget(game: _game!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF0D1117)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 16),
                  _buildSubtitle(),
                  const SizedBox(height: 40),
                  if (_network == null) _buildInitialSelection(),
                  if (_network != null) _buildLobbyContent(),
                  const SizedBox(height: 24),
                  _buildStatusSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + _pulseController.value * 0.05,
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFFF44336)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.3 + _pulseController.value * 0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'MINI MOBA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'ARENA',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 14,
        letterSpacing: 12,
      ),
    );
  }

  Widget _buildInitialSelection() {
    return Column(
      children: [
        _buildNameField(),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'HOST GAME',
                icon: Icons.wifi,
                color: const Color(0xFF2196F3),
                onPressed: _isConnecting ? null : _createHost,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                label: 'JOIN GAME',
                icon: Icons.wifi_find,
                color: const Color(0xFF4CAF50),
                onPressed: _isConnecting ? null : () => _showJoinDialog(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            textStyle: const TextStyle(fontSize: 20),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminScreen()),
            );
          },
          child: const Text('Admin / Customization'),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      onChanged: (v) => _playerName = v.isEmpty ? 'Player' : v,
      decoration: InputDecoration(
        labelText: 'Player Name',
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.person, color: Colors.white54),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildLobbyContent() {
    return Column(
      children: [
        if (_isHost && _peerId.isNotEmpty) _buildPeerIdSection(),
        if (!_isHost) _buildConnectedSection(),
        const SizedBox(height: 24),
        _buildHeroSelection(),
        const SizedBox(height: 24),
        _buildReadyButton(),
      ],
    );
  }

  Widget _buildPeerIdSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            'Your Peer ID',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _peerId,
            style: const TextStyle(
              color: Color(0xFF2196F3),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _copyPeerId,
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy ID'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2196F3)),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          Text(
            'Connected to Host',
            style: TextStyle(color: Color(0xFF4CAF50), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Hero',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _heroKeys.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedHero == index;
              return GestureDetector(
                onTap: () => _selectHero(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2196F3).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2196F3) : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFF2196F3) : Colors.white.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: Text(
                            _heroNames[index][0],
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _heroNames[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _heroRoles[index],
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReadyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isReady ? null : _readyUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isReady ? Colors.grey : const Color(0xFF4CAF50),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          _isReady ? 'READY!' : 'READY UP',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    if (_statusMessage.isEmpty) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_statusMessage),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isConnecting)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
              ),
            if (_isConnecting) const SizedBox(width: 8),
            Text(
              _statusMessage,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('Join Game', style: TextStyle(color: Colors.white)),
        content: TextField(
          onChanged: (v) => _hostIdInput = v,
          decoration: InputDecoration(
            hintText: 'Enter Host Peer ID',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _joinHost();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('Connect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class GameWidget extends StatelessWidget {
  final MobaGame game;

  const GameWidget({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GameCanvas(
          game: game,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
      },
    );
  }
}

class GameCanvas extends StatefulWidget {
  final MobaGame game;
  final double width;
  final double height;

  const GameCanvas({
    super.key,
    required this.game,
    required this.width,
    required this.height,
  });

  @override
  State<GameCanvas> createState() => _GameCanvasState();
}

class _GameCanvasState extends State<GameCanvas> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _joystickDelta = Offset.zero;
  bool _isAttacking = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_onTick);
    _controller.repeat();
    widget.game.setViewSize(widget.width, widget.height);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    widget.game.setMoveInput(_joystickDelta.dx, _joystickDelta.dy);
    widget.game.setAttackInput(_isAttacking);
    widget.game.update(0.016);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.game.getLocalHeroStats();
    return Stack(
      children: [
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: CustomPaint(
            painter: GamePainter(game: widget.game),
          ),
        ),
        GameHud(
          health: stats['hp'] as double,
          maxHealth: stats['maxHp'] as double,
          mana: stats['mana'] as double,
          maxMana: stats['maxMana'] as double,
          gold: stats['gold'] as int,
          kills: stats['kills'] as int,
          deaths: stats['deaths'] as int,
          ping: widget.game.ping,
          fps: 60.0,
          networkQuality: widget.game.networkQuality,
          gameTime: widget.game.gameTime,
          isHost: widget.game.isHost,
        ),
        VirtualJoystick(
          onJoystickMove: (delta) {
            setState(() {
              _joystickDelta = delta;
            });
          },
        ),
        SkillButtons(
          skill1Cooldown: (stats['skill1Cooldown'] as double?) ?? 0,
          skill1MaxCooldown: (stats['skill1MaxCooldown'] as double?) ?? 5,
          skill2Cooldown: (stats['skill2Cooldown'] as double?) ?? 0,
          skill2MaxCooldown: (stats['skill2MaxCooldown'] as double?) ?? 8,
          ultimateCooldown: (stats['ultimateCooldown'] as double?) ?? 0,
          ultimateMaxCooldown: (stats['ultimateMaxCooldown'] as double?) ?? 15,
          onSkill1Pressed: () => widget.game.useSkill(1),
          onSkill2Pressed: () => widget.game.useSkill(2),
          onUltimatePressed: () => widget.game.useSkill(3),
          onAttackPressed: () {
            setState(() {
              _isAttacking = true;
            });
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) setState(() { _isAttacking = false; });
            });
          },
        ),
      ],
    );
  }
}

class GamePainter extends CustomPainter {
  final MobaGame game;

  GamePainter({required this.game});

  @override
  void paint(Canvas canvas, Size size) {
    game.render(canvas);
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}


