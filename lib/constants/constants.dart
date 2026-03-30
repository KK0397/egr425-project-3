/// ============================================================
///  GAME CONSTANTS — fill in your tuning values here
/// ============================================================

class GameConstants {
  // ── Points ───────────────────────────────────────────────
  /// Points the player starts with at the beginning of every round.
  static const int startingPoints = 10; // TODO: adjust as desired

  /// Points needed for the player to WIN the game.
  static const int pointsToWin = 100; // TODO: set your win condition

  /// Points the player must spend to freeze the saboteur.
  static const int pointsToFreeze = 20; // TODO: set freeze cost

  /// How many seconds the saboteur stays frozen after being frozen.
  static const int freezeDurationSeconds = 10; // TODO: set freeze duration

  // ── Fruit spawning ────────────────────────────────────────
  /// Minimum seconds between fruit spawns.
  static const double spawnIntervalMin = 0.8;

  /// Maximum seconds between fruit spawns.
  static const double spawnIntervalMax = 2.0;

  /// How many fruits can be on screen at once before spawning pauses.
  static const int maxFruitsOnScreen = 6;

  /// Points earned per fruit slice.
  static const int pointsPerSlice = 5;

  // ── Physics ───────────────────────────────────────────────
  /// Gravity applied to fruits each second (pixels/s²).
  static const double gravity = 400.0;

  /// Min/max launch speed (pixels/s) for fruits thrown upward.
  static const double launchSpeedMin = 600.0;
  static const double launchSpeedMax = 950.0;

  /// Radius used for hit/slice collision on each fruit (logical pixels).
  static const double fruitRadius = 40.0;
}
