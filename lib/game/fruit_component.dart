import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'fruit_assassin_game.dart';

/// Fruit types — each maps to a Flutter icon and a colour.
/// Swap out icons for any others from Icons.* that you like.
const List<({IconData icon, Color color})> kFruitTypes = [
  (icon: Icons.voice_over_off_sharp, color: Color.fromARGB(255, 170, 32, 30)), // apple (red)
  (icon: Icons.navigation_sharp, color: Color.fromARGB(255, 179, 152, 33)), // lemon (yellow)
  (icon: Icons.visibility_off_sharp, color: Color.fromARGB(255, 27, 150, 33)), // lime (green)
  (icon: Icons.dark_mode_sharp, color: Color.fromARGB(255, 44, 21, 169)), // orange
  (icon: Icons.my_location_sharp, color: Color.fromARGB(255, 94, 16, 167)), // plum (purple)
  (icon: Icons.colorize_sharp, color: Color.fromARGB(255, 171, 92, 27)), // watermelon (pink)
];

/// A single fruit that arcs across the screen, rendered as a Flutter icon.
class FruitComponent extends PositionComponent
    with HasGameRef<FruitAssassinGame> {

  final int fruitTypeIndex;
  late Vector2 _velocity;
  bool _sliced = false;
  bool get sliced => _sliced;

  late final TextPainter _iconPainter;

  FruitComponent({
    required Vector2 startPosition,
    required Vector2 initialVelocity,
    required this.fruitTypeIndex,
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

    final fruit = kFruitTypes[fruitTypeIndex % kFruitTypes.length];

    _iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(fruit.icon.codePoint),
        style: TextStyle(
          fontSize: GameConstants.fruitRadius * 2,
          fontFamily: fruit.icon.fontFamily,
          package: fruit.icon.fontPackage,
          color: fruit.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_sliced) return;

    _velocity.y += GameConstants.gravity * dt;
    position += _velocity * dt;

    if (position.y > gameRef.size.y + GameConstants.fruitRadius * 2) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_sliced) return;

    final offset = Offset(
      (size.x - _iconPainter.width) / 2,
      (size.y - _iconPainter.height) / 2,
    );
    _iconPainter.paint(canvas, offset);
  }

  /// Called by [SliceDetector] when a swipe intersects this fruit.
  void slice() {
    if (_sliced) return;
    _sliced = true;
    gameRef.onFruitSliced();
    removeFromParent();
  }
}

/// ============================================================
///  Fruit Spawner — periodically launches fruits from the bottom
/// ============================================================
class FruitSpawner extends Component with HasGameRef<FruitAssassinGame> {
  final Random _random = Random();
  double _timeSinceLastSpawn = 0;
  double _nextSpawnInterval = 0;

  FruitSpawner() {
    _nextSpawnInterval = _randomInterval();
  }

  double _randomInterval() => GameConstants.spawnIntervalMin +
      _random.nextDouble() *
          (GameConstants.spawnIntervalMax - GameConstants.spawnIntervalMin);

  @override
  void update(double dt) {
    super.update(dt);

    // Count fruits currently on screen
    final fruitsOnScreen = gameRef.children.whereType<FruitComponent>().length;
    if (fruitsOnScreen >= GameConstants.maxFruitsOnScreen) return;

    _timeSinceLastSpawn += dt;
    if (_timeSinceLastSpawn >= _nextSpawnInterval) {
      _timeSinceLastSpawn = 0;
      _nextSpawnInterval = _randomInterval();
      _spawnFruit();
    }
  }

  void _spawnFruit() {
    final screenWidth  = gameRef.size.x;
    final screenHeight = gameRef.size.y;

    // Random horizontal position, spawned just below the screen
    final x = GameConstants.fruitRadius +
        _random.nextDouble() * (screenWidth - GameConstants.fruitRadius * 2);
    final startPos = Vector2(x, screenHeight + GameConstants.fruitRadius);

    // Random upward velocity with slight horizontal drift
    final speed = GameConstants.launchSpeedMin +
        _random.nextDouble() *
            (GameConstants.launchSpeedMax - GameConstants.launchSpeedMin);
    final angle = -pi / 2 + (_random.nextDouble() - 0.5) * (pi / 4);
    final velocity = Vector2(cos(angle) * speed, sin(angle) * speed);

    gameRef.add(FruitComponent(
      startPosition: startPos,
      initialVelocity: velocity,
      fruitTypeIndex: _random.nextInt(kFruitTypes.length),
    ));
  }
}
