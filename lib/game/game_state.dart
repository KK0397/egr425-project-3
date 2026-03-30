import 'dart:async';
import '../constants/constants.dart';
import '../ble/ble_manager.dart';

enum GameStatus { playing, won, lost }

/// ============================================================
///  GameState — pure Dart model, no Flame dependency
/// ============================================================
class GameState {
  // ── Points ─────────────────────────────────────────────────
  int _playerPoints = GameConstants.startingPoints;
  int get playerPoints => _playerPoints;

  // ── Freeze ─────────────────────────────────────────────────
  bool _saboteurFrozen = false;
  bool get saboteurFrozen => _saboteurFrozen;

  Timer? _freezeTimer;

  // ── Status ─────────────────────────────────────────────────
  GameStatus _status = GameStatus.playing;
  GameStatus get status => _status;

  // ── Change notifications ────────────────────────────────────
  final StreamController<GameState> _changeController =
      StreamController<GameState>.broadcast();
  Stream<GameState> get onChange => _changeController.stream;

  void _notify() => _changeController.add(this);

  // ── Player actions ──────────────────────────────────────────

  /// Called when the player slices a fruit.
  void onFruitSliced() {
    if (_status != GameStatus.playing) return;
    _playerPoints += GameConstants.pointsPerSlice;
    if (_playerPoints >= GameConstants.pointsToWin) {
      _status = GameStatus.won;
      BleManager.instance.sendWin(); // ← add this
    }
    _notify();
  }

  /// Called when the player accidentally slices a bomb.
  void onBombSliced() {
    if (_status != GameStatus.playing) return;
    _playerPoints -= GameConstants.bombPenalty; // add this constant
    if (_playerPoints <= 0) {
      _playerPoints = 0;
      _status = GameStatus.lost;
    }
    _notify();
  }

  /// Called when the player taps the "Freeze Saboteur" button.
  /// Returns true if the freeze was successfully activated.
  bool tryFreezeSaboteur() {
    if (_status != GameStatus.playing) return false;
    if (_saboteurFrozen) return false; // already frozen
    if (_playerPoints < GameConstants.pointsToFreeze) return false;

    _playerPoints -= GameConstants.pointsToFreeze;
    _saboteurFrozen = true;
    BleManager.instance.sendFreeze();

    _freezeTimer?.cancel();
    _freezeTimer = Timer(
      Duration(seconds: GameConstants.freezeDurationSeconds),
      _unfreeze,
    );

    _notify();
    return true;
  }

  void _unfreeze() {
    _saboteurFrozen = false;
    BleManager.instance.sendUnfreeze();
    _notify();
  }

  // ── Sabotage handling ───────────────────────────────────────

  /// Handle an incoming sabotage command from the M5Core2.
  /// Returns the command only if the saboteur is NOT frozen.

  SabotageCommand? receiveSabotage(SabotageCommand cmd) {
    if (_saboteurFrozen) return null;
    if (_status != GameStatus.playing) return null;

    // Saboteur win ends the game immediately
    if (cmd == SabotageCommand.saboteurWin) {
      _status = GameStatus.lost;
      _notify();
      return null; // no visual effect needed, HUD will react
    }

    return cmd;
  }

  // ── Cleanup ─────────────────────────────────────────────────

  void dispose() {
    _freezeTimer?.cancel();
    _changeController.close();
  }
}
