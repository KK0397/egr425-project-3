import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../ble/ble_manager.dart';
import '../game/fruit_assassin_game.dart';
import '../game/hud_overlay.dart';
import 'game_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _connecting = false;
  bool _connected = false;
  String _statusMessage = 'Not connected to saboteur';

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _statusMessage = 'Scanning for M5Core2…';
    });

    try {
      await BleManager.instance.scanAndConnect();
      setState(() {
        _connected = true;
        _statusMessage = 'Connected to saboteur!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection failed: $e';
        print(e);
      });
    } finally {
      setState(() => _connecting = false);
    }
  }

  void _startGame() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              const Text(
                'FRUIT ASSASSIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  fontFamily: 'monospace',
                ),
              ),
              const Text(
                'vs. THE SABOTEUR',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 16,
                  letterSpacing: 3,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 60),

              // BLE status
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _connected ? Icons.bluetooth_connected : Icons.bluetooth,
                      color: _connected ? Colors.cyanAccent : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _connected ? Colors.cyanAccent : Colors.white54,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Connect button
              if (!_connected)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                  onPressed: _connecting ? null : _connect,
                  icon: _connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(
                    _connecting ? 'Connecting…' : 'Connect to M5Core2',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),

              const SizedBox(height: 16),

              // Start game button (only enabled when connected)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _connected ? Colors.cyanAccent : Colors.grey.shade800,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                onPressed: _connected ? _startGame : null,
                // onPressed: _startGame,
                child: const Text(
                  'START GAME',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
