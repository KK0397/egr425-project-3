import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:proj3_fixed/game/sabotage_handler.dart';
import '../constants/constants.dart';
import 'fruit_component.dart';
import 'fruit_assassin_game.dart';

/// Covers the full screen and detects drag (swipe) gestures.
/// When a drag path crosses a [FruitComponent], that fruit is sliced.
class SliceDetector extends PositionComponent
    with HasGameRef<FruitAssassinGame>, DragCallbacks {
  // The last recorded pointer position during a drag
  Vector2? _lastDragPos;

  // Visual slice trail
  final List<Offset> _trailPoints = [];
  static const int _maxTrailPoints = 20;

  // Paint for the slice trail
  final Paint _trailPaint = Paint()
    ..color = Colors.white.withOpacity(0.6)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Size to fill the whole game canvas
    size = gameRef.size;
    priority = 10; // render on top of fruits
  }

  // ── Drag callbacks ───────────────────────────────────────────

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _lastDragPos = event.canvasPosition.clone();
    _trailPoints.clear();
    _trailPoints.add(Offset(event.canvasPosition.x, event.canvasPosition.y));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final current = event.renderingTrace.last.end;

    // Add to visual trail
    _trailPoints.add(Offset(current.x, current.y));
    if (_trailPoints.length > _maxTrailPoints) {
      _trailPoints.removeAt(0);
    }

    if (_lastDragPos != null) {
      _checkSlice(_lastDragPos!, current);
    }
    _lastDragPos = current.clone();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _lastDragPos = null;
    _trailPoints.clear();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _lastDragPos = null;
    _trailPoints.clear();
  }

  // ── Slice logic ──────────────────────────────────────────────

  /// Tests whether the line segment [from]→[to] intersects any fruit.
  void _checkSlice(Vector2 from, Vector2 to) {
    // Check fruits
    final fruits = gameRef.children.whereType<FruitComponent>().toList();
    for (final fruit in fruits) {
      if (fruit.sliced) continue;
      final center = fruit.position;
      if (_segmentIntersectsCircle(
          from, to, center, GameConstants.fruitRadius)) {
        fruit.slice();
      }
    }

    // Check bombs
    final bombs = gameRef.children.whereType<BombComponent>().toList();
    for (final bomb in bombs) {
      if (bomb.triggered) continue;
      final center = bomb.position;
      if (_segmentIntersectsCircle(
          from, to, center, GameConstants.fruitRadius)) {
        bomb.trigger();
      }
    }
  }

  /// Returns true if line segment AB passes within [radius] of [center].
  bool _segmentIntersectsCircle(
      Vector2 a, Vector2 b, Vector2 center, double radius) {
    final ab = b - a;
    final ac = center - a;
    final abLenSq = ab.length2;
    if (abLenSq == 0) return ac.length <= radius;

    // Project ac onto ab, clamped to [0,1]
    final t = (ac.dot(ab) / abLenSq).clamp(0.0, 1.0);
    final closest = a + ab * t;
    return (center - closest).length <= radius;
  }

  // ── Render trail ─────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_trailPoints.length < 2) return;

    final path = Path()..moveTo(_trailPoints.first.dx, _trailPoints.first.dy);
    for (int i = 1; i < _trailPoints.length; i++) {
      path.lineTo(_trailPoints[i].dx, _trailPoints[i].dy);
    }
    canvas.drawPath(path, _trailPaint);
  }
}
