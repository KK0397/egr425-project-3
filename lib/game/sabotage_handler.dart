import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../ble/ble_manager.dart';
import '../constants/constants.dart';
import 'fruit_assassin_game.dart';
import 'fruit_component.dart';

class SabotageHandler {
  SabotageHandler._();

  // Track active effects so we don't stack them
  static bool _blindActive = false;

  static void handle(SabotageCommand cmd, FruitAssassinGame game) {
    switch (cmd) {
      case SabotageCommand.spawnBomb:
        _handleSpawnBomb(game);
        break;
      case SabotageCommand.blind:
        _handleBlind(game);
        break;
      case SabotageCommand.unknown:
        break;
      case SabotageCommand.saboteurWin:
        break;
    }
  }

  // ── Bomb ─────────────────────────────────────────────────────
  // Spawns a bomb that looks distinct from fruit. If sliced, deducts points.

  static void _handleSpawnBomb(FruitAssassinGame game) {
    final random = Random();
    final screenWidth = game.size.x;
    final screenHeight = game.size.y;

    final x = GameConstants.fruitRadius +
        random.nextDouble() * (screenWidth - GameConstants.fruitRadius * 2);
    final startPos = Vector2(x, screenHeight + GameConstants.fruitRadius);

    final speed = GameConstants.launchSpeedMin +
        random.nextDouble() *
            (GameConstants.launchSpeedMax - GameConstants.launchSpeedMin);
    final angle = -pi / 2 + (random.nextDouble() - 0.5) * (pi / 4);
    final velocity = Vector2(cos(angle) * speed, sin(angle) * speed);

    game.add(BombComponent(startPosition: startPos, initialVelocity: velocity));
  }

  // ── Blind ─────────────────────────────────────────────────────
  // Covers the screen with a dark overlay for a few seconds.

  static void _handleBlind(FruitAssassinGame game) {
    if (_blindActive) return;
    _blindActive = true;
    game.add(BlindOverlay());
  }

  static void onBlindEnd() {
    _blindActive = false;
  }
}

// ── BombComponent ─────────────────────────────────────────────

class BombComponent extends PositionComponent
    with HasGameRef<FruitAssassinGame> {
  late Vector2 _velocity;

  bool _triggered = false;
  bool get triggered => _triggered;

  late final TextPainter _painter;

  BombComponent({
    required Vector2 startPosition,
    required Vector2 initialVelocity,
  }) : super(
          position: startPosition,
          size: Vector2.all(GameConstants.fruitRadius * 2),
          anchor: Anchor.center,
        ) {
    _velocity = initialVelocity;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.crisis_alert.codePoint),
        style: TextStyle(
          fontSize: GameConstants.fruitRadius * 2,
          fontFamily: Icons.crisis_alert.fontFamily,
          package: Icons.crisis_alert.fontPackage,
          color: Colors.red,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_triggered) return;

    _velocity.y += GameConstants.gravity * dt;
    position += _velocity * dt;

    if (position.y > gameRef.size.y + GameConstants.fruitRadius * 2) {
      removeFromParent(); // missed — no penalty
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_triggered) return;
    final offset = Offset(
      (size.x - _painter.width) / 2,
      (size.y - _painter.height) / 2,
    );
    _painter.paint(canvas, offset);
  }

  /// Called by SliceDetector when this bomb is hit.
  void trigger() {
    if (_triggered) return;
    _triggered = true;
    gameRef.gameState.onBombSliced(); // deduct points
    removeFromParent();
  }
}

// ── BlindOverlay ──────────────────────────────────────────────

class BlindOverlay extends Component with HasGameRef<FruitAssassinGame> {
  static const double _duration = 4.0; // seconds
  double _elapsed = 0;

  final Paint _paint = Paint()..color = const Color(0xEE000000);

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _duration) {
      SabotageHandler.onBlindEnd();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y),
      _paint,
    );
  }

  @override
  int get priority => 10; // render on top of everything
}
