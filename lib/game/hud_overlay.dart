import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'game_state.dart';
import 'fruit_assassin_game.dart';

/// ============================================================
///  HUD Overlay
///
///  Rendered as a Flutter widget on top of the Flame canvas.
///  Shows player points, freeze button, freeze status, and
///  the win/loss banner.
/// ============================================================
class HudOverlay extends StatefulWidget {
  final FruitAssassinGame game;

  const HudOverlay({super.key, required this.game});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  late GameState _gs;

  @override
  void initState() {
    super.initState();
    _gs = widget.game.gameState;
    _gs.onChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Top bar ────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _TopBar(
            gameState: _gs,
            onFreezePressed: () => widget.game.tryFreezeSaboteur(),
          ),
        ),

        // ── Win / Loss banner ──────────────────────────────────
        if (_gs.status != GameStatus.playing)
          _GameOverBanner(status: _gs.status),
      ],
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final GameState gameState;
  final VoidCallback onFreezePressed;

  const _TopBar({required this.gameState, required this.onFreezePressed});

  @override
  Widget build(BuildContext context) {
    final canFreeze = gameState.playerPoints >= GameConstants.pointsToFreeze &&
        !gameState.saboteurFrozen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black54,
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Points display
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'POINTS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  '${gameState.playerPoints}  /  ${GameConstants.pointsToWin}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),

            // Freeze button
            GestureDetector(
              onTap: canFreeze ? onFreezePressed : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: gameState.saboteurFrozen
                      ? Colors.lightBlue.shade700
                      : canFreeze
                          ? Colors.cyanAccent.shade700
                          : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: gameState.saboteurFrozen
                        ? Colors.lightBlueAccent
                        : canFreeze
                            ? Colors.cyanAccent
                            : Colors.grey,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      gameState.saboteurFrozen
                          ? Icons.ac_unit
                          : Icons.lock_clock,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      gameState.saboteurFrozen
                          ? 'FROZEN  (${GameConstants.freezeDurationSeconds}s)'
                          : 'FREEZE  -${GameConstants.pointsToFreeze}pts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Win / Loss banner ─────────────────────────────────────────

class _GameOverBanner extends StatelessWidget {
  final GameStatus status;

  const _GameOverBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final isWin = status == GameStatus.won;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWin ? Colors.cyanAccent : Colors.redAccent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isWin ? '🏆  YOU WIN!' : '💀  GAME OVER',
              style: TextStyle(
                color: isWin ? Colors.cyanAccent : Colors.redAccent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isWin
                  ? 'You outsmarted the saboteur!'
                  : 'The saboteur got the better of you.',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isWin ? Colors.cyanAccent : Colors.redAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              onPressed: () {
                // TODO: wire up restart or navigate back to menu
                Navigator.of(context).pop();
              },
              child: const Text(
                'BACK TO MENU',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
