import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/fruit_assassin_game.dart';
import '../game/hud_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final FruitAssassinGame _game;

  @override
  void initState() {
    super.initState();
    _game = FruitAssassinGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Flame game canvas
          GameWidget(
            game: _game,
          ),

          // Flutter HUD rendered on top
          HudOverlay(game: _game),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
