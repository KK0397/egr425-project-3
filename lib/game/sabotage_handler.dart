import '../ble/ble_manager.dart';
import 'fruit_assassin_game.dart';

/// ============================================================
///  SabotageHandler
///
///  Add your sabotage effect implementations here.
///  Each case in handle() corresponds to a [SabotageCommand]
///  that your M5Core2 can send over BLE.
/// ============================================================
class SabotageHandler {
  SabotageHandler._();

  static void handle(SabotageCommand cmd, FruitAssassinGame game) {
    switch (cmd) {
      case SabotageCommand.spawnBomb:
        _handleSpawnBomb(game);
        break;

      case SabotageCommand.slowSlicing:
        _handleSlowSlicing(game);
        break;

      case SabotageCommand.invertControls:
        _handleInvertControls(game);
        break;

      // TODO: add cases for any additional SabotageCommand values
      // you define in ble_manager.dart, following the same pattern.

      case SabotageCommand.unknown:
        // Unrecognised command — do nothing.
        break;
    }
  }

  // ── Individual effect handlers ────────────────────────────────

  /// TODO: Implement the "spawn bomb" effect.
  /// Suggestion: add a BombComponent to the game that the player
  /// must avoid slicing. If sliced, deduct points or end the game.
  static void _handleSpawnBomb(FruitAssassinGame game) {
    // TODO: game.add(BombComponent(...));
  }

  /// TODO: Implement the "slow slicing" effect.
  /// Suggestion: temporarily widen the slice detection window
  /// (i.e. require a faster swipe) or reduce [GameConstants.fruitRadius]
  /// for a set duration via a timer.
  static void _handleSlowSlicing(FruitAssassinGame game) {
    // TODO: apply timed effect
  }

  /// TODO: Implement the "invert controls" effect.
  /// Suggestion: set a flag on [SliceDetector] that flips the swipe
  /// direction math for a few seconds.
  static void _handleInvertControls(FruitAssassinGame game) {
    // TODO: apply timed effect
  }
}
