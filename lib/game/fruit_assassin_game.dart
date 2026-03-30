import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../ble/ble_manager.dart';
import '../constants/constants.dart';
import 'fruit_component.dart';
import 'game_state.dart';
import 'sabotage_handler.dart';
import 'slice_detector.dart';
import 'package:flame/components.dart';

/// ============================================================
///  FruitAssassinGame — root Flame game
/// ============================================================
class FruitAssassinGame extends FlameGame {
  final GameState gameState = GameState();

  late final StreamSubscription<SabotageCommand> _bleSub;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Background
    add(BackgroundComponent());

    // Fruit spawner
    add(FruitSpawner());

    // Gesture/slice detection overlay
    add(SliceDetector());

    // Listen for BLE sabotage commands from the M5Core2
    _bleSub = BleManager.instance.sabotageStream.listen(_onSabotageReceived);
  }

  // ── Fruit sliced callback (called by FruitComponent) ─────────

  void onFruitSliced() {
    gameState.onFruitSliced();
    // The HUD overlay reads from gameState.onChange — no extra wiring needed.
  }

  // ── Sabotage ─────────────────────────────────────────────────

  void _onSabotageReceived(SabotageCommand cmd) {
    final active = gameState.receiveSabotage(cmd);
    if (active == null) return; // saboteur is frozen — ignore

    // Delegate to the sabotage handler
    SabotageHandler.handle(cmd, this);
  }

  // ── Freeze saboteur (called from HUD button) ──────────────────

  /// Returns true if the freeze was applied (enough points, not already frozen).
  bool tryFreezeSaboteur() => gameState.tryFreezeSaboteur();

  // ── Cleanup ───────────────────────────────────────────────────

  @override
  void onRemove() {
    _bleSub.cancel();
    gameState.dispose();
    super.onRemove();
  }
}

/// ============================================================
///  Simple solid-colour background
/// ============================================================
class BackgroundComponent extends Component with HasGameRef<FruitAssassinGame> {
  final Paint _paint = Paint()..color = const Color(0xFF1A1A2E);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y),
      _paint,
    );
  }
}
