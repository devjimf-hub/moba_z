import 'dart:async';
import 'dart:math';
import 'package:peerdart/peerdart.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';
import 'packet_parser.dart';

typedef OnPacketReceived = void Function(GamePacket packet);
typedef OnConnectionChanged = void Function(bool connected);

class NetworkManager {
  late Peer _peer;
  String? _hostPeerId;
  final String _playerName;
  bool _isHost = false;
  bool _isConnected = false;

  final Map<String, DataConnection> _connections = {};
  DataConnection? _hostConnection;

  OnPacketReceived? onPacketReceived;
  OnConnectionChanged? onConnectionChanged;

  final Map<int, double> _pingHistory = {};
  double _avgPing = 0;
  double _jitter = 0;
  int _pingSequence = 0;
  Timer? _pingTimer;
  final List<double> _recentPings = [];

  String get peerId => _peer.id ?? '';
  String get hostPeerId => _hostPeerId ?? '';
  bool get isHost => _isHost;
  bool get isConnected => _isConnected;
  double get ping => _avgPing;
  double get jitter => _jitter;
  int get connectionCount => _connections.length;

  NetworkManager({
    required String playerName,
    this.onPacketReceived,
    this.onConnectionChanged,
  }) : _playerName = playerName;

  Future<void> initHost() async {
    _isHost = true;
    _peer = Peer(id: const Uuid().v4().substring(0, 8));

    _peer.on('connection').listen((dynamic conn) {
      if (conn is DataConnection) {
        _handleNewConnection(conn);
      }
    });

    _peer.on('disconnected').listen((_) {
      _handleDisconnect();
    });

    _peer.on('open').listen((_) {
      _isConnected = true;
      onConnectionChanged?.call(true);
      _startPingTimer();
    });

    _hostPeerId = peerId;
  }

  Future<String?> initClient(String hostId) async {
    _isHost = false;
    _peer = Peer(id: const Uuid().v4().substring(0, 8));

    _peer.on('disconnected').listen((_) {
      _handleDisconnect();
    });

    _peer.on('open').listen((_) async {
      try {
        final conn = _peer.connect(hostId);
        _handleHostConnection(conn);
        _hostPeerId = hostId;
      } catch (e) {
        onConnectionChanged?.call(false);
      }
    });

    return peerId;
  }

  void _handleNewConnection(DataConnection conn) {
    final channelId = conn.connectionId ?? 'unknown';
    _connections[channelId] = conn;

    conn.on('data').listen((data) {
      if (data is String) {
        _onMessage(data);
      }
    });

    conn.on('close').listen((_) {
      _connections.remove(channelId);
      _notifyConnectionChange();
    });

    sendPacket(GamePacket(
      type: PacketType.playerJoin,
      data: '${_peer.id}:$_playerName',
    ));

    _notifyConnectionChange();
  }

  void _handleHostConnection(DataConnection conn) {
    _hostConnection = conn;

    conn.on('open').listen((_) {
      _isConnected = true;
      onConnectionChanged?.call(true);
      _startPingTimer();
    });

    conn.on('data').listen((data) {
      if (data is String) {
        _onMessage(data);
      }
    });

    conn.on('close').listen((_) {
      _hostConnection = null;
      _handleDisconnect();
    });
  }

  void _onMessage(String raw) {
    final packet = PacketParser.decode(raw);
    if (packet != null) {
      if (packet.type == PacketType.ping) {
        _handlePingResponse(packet);
      } else {
        onPacketReceived?.call(packet);
      }
    }
  }

  void sendPacket(GamePacket packet) {
    final raw = PacketParser.encode(packet);
    for (final entry in _connections.entries) {
      try {
        entry.value.send(raw);
      } catch (_) {}
    }
  }

  void sendToHost(GamePacket packet) {
    if (_isHost) return;
    if (_hostConnection != null) {
      try {
        _hostConnection!.send(PacketParser.encode(packet));
      } catch (_) {}
    }
  }

  void broadcastToClients(GamePacket packet) {
    if (!_isHost) return;
    final raw = PacketParser.encode(packet);
    for (final entry in _connections.entries) {
      try {
        entry.value.send(raw);
      } catch (_) {}
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pingSequence++;
      final pingData = PacketParser.encodePing(_pingSequence);
      if (_isHost) {
        sendPacket(GamePacket(type: PacketType.ping, data: pingData));
      } else {
        sendToHost(GamePacket(type: PacketType.ping, data: pingData));
      }
    });
  }

  void _handlePingResponse(GamePacket packet) {
    final parsed = PacketParser.parsePing(packet.data);
    if (parsed == null) return;

    if (_isHost) {
      // Host received a ping request from client — echo it back
      sendPacket(GamePacket(
        type: PacketType.ping,
        data: PacketParser.encodePing(parsed['seq'] as int),
      ));
      return;
    }

    // Client received the echo — compute round-trip latency
    final latency = (parsed['received'] as int) - (parsed['sent'] as int);
    _pingHistory[parsed['seq'] as int] = latency.toDouble();
    _recentPings.add(latency.toDouble());
    if (_recentPings.length > 10) _recentPings.removeAt(0);
    _avgPing = _recentPings.reduce((a, b) => a + b) / _recentPings.length;
    if (_recentPings.length > 1) {
      final mean = _avgPing;
      double variance = 0;
      for (final p in _recentPings) {
        variance += (p - mean) * (p - mean);
      }
      _jitter = sqrt(variance / _recentPings.length);
    }
  }

  double getNetworkQuality() {
    if (_avgPing < 50) return 1.0;
    if (_avgPing < 100) return 0.8;
    if (_avgPing < 200) return 0.5;
    return 0.2;
  }

  void _handleDisconnect() {
    _isConnected = false;
    onConnectionChanged?.call(false);
    _pingTimer?.cancel();
  }

  void _notifyConnectionChange() {
    onConnectionChanged?.call(_connections.isNotEmpty || _hostConnection != null);
  }

  void disconnect() {
    _pingTimer?.cancel();
    for (final conn in _connections.values) {
      try {
        conn.close();
      } catch (_) {}
    }
    _connections.clear();
    try {
      _hostConnection?.close();
    } catch (_) {}
    _hostConnection = null;
    try {
      _peer.disconnect();
    } catch (_) {}
    _isConnected = false;
  }

  void dispose() {
    disconnect();
  }
}
