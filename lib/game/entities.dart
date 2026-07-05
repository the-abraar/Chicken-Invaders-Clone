import 'dart:math';
import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────
enum GamePhase { getReady, riding, gameOver }
enum ObstacleType { rickshaw, cng, bus, dog, pothole }
enum PickupKind { cash, tea, wrench }

// ── Obstacle (traffic, dogs, potholes) ────────────────────────────────────────
class Obstacle {
  final ObstacleType type;
  double x, y;        // screen coords, centre
  double ownSpeed;    // forward speed (subtracted from scroll)
  double vx = 0;      // lateral velocity (dogs cross, honk shoves)
  double weaveT;      // CNG weave phase
  final int seed;     // stable per-entity variation (bus colour etc.)
  bool active = true;
  bool fleeing = false; // dog scared off by honk
  bool shaved = false;  // near-miss already counted

  Obstacle({required this.type, required this.x, required this.y,
      required this.ownSpeed, required this.seed})
      : weaveT = Random().nextDouble() * 6.28;

  double get w => switch (type) {
        ObstacleType.rickshaw => 34,
        ObstacleType.cng      => 36,
        ObstacleType.bus      => 62,
        ObstacleType.dog      => 26,
        ObstacleType.pothole  => 38,
      };

  double get h => switch (type) {
        ObstacleType.rickshaw => 52,
        ObstacleType.cng      => 56,
        ObstacleType.bus      => 128,
        ObstacleType.dog      => 22,
        ObstacleType.pothole  => 22,
      };
}

// ── Sergeant (roadside mamla thrower) ─────────────────────────────────────────
class Sergeant {
  double x, y;
  final int side; // -1 left shoulder, 1 right shoulder
  double throwT;
  double staggerT = 0; // honked-at: can't throw
  bool active = true;

  Sergeant({required this.x, required this.y, required this.side})
      : throwT = 0.6 + Random().nextDouble() * 0.8;
}

// ── Mamla (flying court case) ─────────────────────────────────────────────────
class Mamla {
  double x, y, vx, vy, angle = 0, spin;
  bool active = true;

  Mamla({required this.x, required this.y, required this.vx, required this.vy})
      : spin = (Random().nextDouble() - 0.5) * 5;
}

// ── Roadside pickups ──────────────────────────────────────────────────────────
class RoadPickup {
  double x, y;
  final PickupKind kind;
  final int value; // ৳ for cash
  bool active = true;

  RoadPickup({required this.x, required this.y, required this.kind, this.value = 0});

  String get emoji => switch (kind) {
        PickupKind.cash   => '💵',
        PickupKind.tea    => '☕',
        PickupKind.wrench => '🔧',
      };
}

// ── Fare markers ──────────────────────────────────────────────────────────────
class FareMarker {
  double x, y;
  final bool dropoff;
  bool active = true;

  FareMarker({required this.x, required this.y, required this.dropoff});
}

// ── Police car ────────────────────────────────────────────────────────────────
class PoliceCar {
  double x, y;
  bool active = true;
  bool leaving = false; // wanted hit 0 — drives off

  PoliceCar({required this.x, required this.y});
}

// ── Explosion ─────────────────────────────────────────────────────────────────
class Explosion {
  final double ox, oy;
  double progress = 0; // 0 → 1
  final String label;
  final List<Particle> parts;
  static final _rng = Random();

  Explosion({required this.ox, required this.oy, this.label = ''})
      : parts = List.generate(14, (_) {
          final a = _rng.nextDouble() * pi * 2;
          final s = 45 + _rng.nextDouble() * 120;
          return Particle(
            vx: cos(a) * s,
            vy: sin(a) * s,
            color: [
              Colors.orange,
              Colors.yellow,
              Colors.red,
              Colors.white,
              const Color(0xFFFF6B35),
            ][_rng.nextInt(5)],
            r: 2.5 + _rng.nextDouble() * 4,
          );
        });

  List<Particle> get particles => parts;
}

class Particle {
  double x = 0, y = 0;
  double vx, vy;
  final Color color;
  final double r;
  Particle({required this.vx, required this.vy, required this.color, required this.r});
}

// ── FloatingText ──────────────────────────────────────────────────────────────
class FloatingText {
  double x, y;
  final double vy = -55;
  double opacity = 1.0;
  final String text;
  final Color color;
  FloatingText({required this.x, required this.y, required this.text, required this.color});
}
