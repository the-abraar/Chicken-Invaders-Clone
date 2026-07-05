import 'dart:math';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'entities.dart';
import 'game_engine.dart';
import 'save_data.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;
  final double t; // wall-clock time for ambient animation

  GamePainter(this.engine, this.t);

  final _pFill = Paint()..style = PaintingStyle.fill;
  final _pStr  = Paint()..style = PaintingStyle.stroke;

  static final _rng = Random();

  // Bike paint job per engine tier — your hustle, visible.
  static const _tierColors = [
    Color(0xFF7A4A2B), // rusty brown — the crappy starter bike
    Color(0xFFB3282D), // red
    Color(0xFFE86A17), // orange
    Color(0xFF1B9AAA), // teal
    Color(0xFF7B2FBE), // purple
    Color(0xFFD4AF37), // gold — full tyrant
  ];

  // TextPainter layout is the most expensive per-frame cost. Cache by
  // text/size/color; alpha quantized so fading text still hits the cache.
  static final Map<String, TextPainter> _tpCache = {};

  static TextPainter _tp(String text, double fontSize, Color color, {bool emoji = false}) {
    final a = ((color.a * 20).round() / 20).clamp(0.0, 1.0);
    final c = color.withValues(alpha: a);
    final key = '$text|$fontSize|${c.toARGB32()}|$emoji';
    var tp = _tpCache[key];
    if (tp == null) {
      if (_tpCache.length > 300) {
        final stale = _tpCache.keys.take(150).toList();
        for (final k in stale) {
          _tpCache.remove(k);
        }
      }
      tp = TextPainter(
        text: TextSpan(
          text: text,
          style: emoji
              ? TextStyle(fontSize: fontSize)
              : TextStyle(
                  fontSize: fontSize,
                  color: c,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 340);
      _tpCache[key] = tp;
    }
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (engine.shake > 0) {
      final dx = (_rng.nextDouble() - 0.5) * 10 * engine.shake;
      final dy = (_rng.nextDouble() - 0.5) * 10 * engine.shake;
      canvas.save();
      canvas.translate(dx, dy);
    }

    _drawGround(canvas, size);
    _drawRoad(canvas, size);
    _drawRoadside(canvas, size);

    // World entities, back-to-front
    for (final o in engine.obstacles) {
      if (o.type == ObstacleType.pothole) _drawPothole(canvas, o);
    }
    _drawMarkers(canvas);
    _drawPickups(canvas);
    for (final s in engine.sergeants) {
      _drawSergeant(canvas, s);
    }
    for (final o in engine.obstacles) {
      switch (o.type) {
        case ObstacleType.rickshaw: _drawRickshaw(canvas, o);
        case ObstacleType.cng:      _drawCng(canvas, o);
        case ObstacleType.bus:      _drawBus(canvas, o);
        case ObstacleType.dog:      _drawDog(canvas, o);
        case ObstacleType.pothole:  break; // already drawn under traffic
      }
    }
    _drawPolice(canvas);
    _drawMamlas(canvas);
    _drawBike(canvas);
    _drawExplosions(canvas);
    _drawFloatingTexts(canvas);

    if (engine.shake > 0) canvas.restore();

    _drawHUD(canvas, size);

    if (engine.phase == GamePhase.getReady) _drawGetReady(canvas, size);
    if (engine.phase == GamePhase.gameOver) _drawKaput(canvas, size);
  }

  // ── Ground / road ─────────────────────────────────────────────────────────────

  void _drawGround(Canvas canvas, Size size) {
    _pFill.color = const Color(0xFF10131A); // night-time sidewalks
    canvas.drawRect(Offset.zero & size, _pFill);
  }

  void _drawRoad(Canvas canvas, Size size) {
    final l = engine.roadL, r = engine.roadR;
    _pFill.color = const Color(0xFF23252B);
    canvas.drawRect(Rect.fromLTRB(l, 0, r, size.height), _pFill);

    // Edge lines
    _pFill.color = const Color(0xFFB9B9B9).withValues(alpha: 0.5);
    canvas.drawRect(Rect.fromLTWH(l, 0, 3, size.height), _pFill);
    canvas.drawRect(Rect.fromLTWH(r - 3, 0, 3, size.height), _pFill);

    // Lane dashes scroll DOWN as you ride forward.
    const dashH = 26.0, gap = 22.0, period = dashH + gap;
    final off = engine.worldOffset % period;
    _pFill.color = const Color(0xFFFFDD00).withValues(alpha: 0.4);
    for (int lane = 1; lane < kLanes; lane++) {
      final x = l + engine.laneW * lane;
      for (double y = off - period; y < size.height + period; y += period) {
        canvas.drawRect(Rect.fromLTWH(x - 2, y, 4, dashH), _pFill);
      }
    }
  }

  static const _props = ['🌳', '🏚️', '🏪', '🛖', '🌴', '🏬', '🕌', '🌳'];

  void _drawRoadside(Canvas canvas, Size size) {
    const period = 96.0;
    final off = engine.worldOffset;
    final rowStart = ((off - 60) / period).floor();
    final rowEnd   = ((off + size.height + 60) / period).ceil();
    for (int side = 0; side < 2; side++) {
      final baseX = side == 0 ? engine.roadL * 0.5 : size.width - engine.roadL * 0.5;
      for (int row = rowStart; row <= rowEnd; row++) {
        final worldY = row * period;
        final y = size.height - (worldY - off);
        if (y < -60 || y > size.height + 60) continue;
        final rng = Random(row * 31 + side * 7 + 3);
        if (rng.nextDouble() < 0.22) {
          // Street lamp with warm glow
          _pFill.color = const Color(0xFFFFB84D).withValues(alpha: 0.12);
          canvas.drawCircle(Offset(baseX, y), 26, _pFill);
          _pFill.color = const Color(0xFFFFB84D);
          canvas.drawCircle(Offset(baseX, y), 3, _pFill);
        } else {
          final e = _props[rng.nextInt(_props.length)];
          _drawEmoji(canvas, e, baseX + (rng.nextDouble() - 0.5) * 14, y,
              20 + rng.nextInt(3) * 4.0);
        }
      }
    }
  }

  // ── Traffic ───────────────────────────────────────────────────────────────────

  void _drawPothole(Canvas canvas, Obstacle o) {
    _pFill.color = const Color(0xFF15161A);
    canvas.drawOval(Rect.fromCenter(center: Offset(o.x, o.y), width: o.w, height: o.h), _pFill);
    _pFill.color = const Color(0xFF0A0B0E);
    canvas.drawOval(Rect.fromCenter(center: Offset(o.x, o.y + 1), width: o.w * 0.7, height: o.h * 0.6), _pFill);
  }

  static const _canopyColors = [
    Color(0xFFE63946), Color(0xFF457B9D), Color(0xFF2A9D8F),
    Color(0xFFF4A261), Color(0xFF9B5DE5),
  ];

  void _drawRickshaw(Canvas canvas, Obstacle o) {
    final x = o.x, y = o.y;
    // Wheels
    _pFill.color = const Color(0xFF15161A);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x - 14, y + 12), width: 5, height: 20), const Radius.circular(2)), _pFill);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x + 14, y + 12), width: 5, height: 20), const Radius.circular(2)), _pFill);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y - 20), width: 5, height: 16), const Radius.circular(2)), _pFill);
    // Body
    _pFill.color = const Color(0xFF3A3D46);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y - 4), width: 22, height: 36), const Radius.circular(4)), _pFill);
    // Canopy over the rear (passenger seat)
    _pFill.color = _canopyColors[o.seed % _canopyColors.length];
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y + 10), width: 30, height: 26), const Radius.circular(9)), _pFill);
    _pFill.color = Colors.white.withValues(alpha: 0.25);
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y + 10), width: 30, height: 3), _pFill);
    // Puller
    _pFill.color = const Color(0xFFE0B084);
    canvas.drawCircle(Offset(x, y - 16), 5, _pFill);
  }

  void _drawCng(Canvas canvas, Obstacle o) {
    final x = o.x, y = o.y;
    // Body — the classic green baby taxi
    _pFill.color = const Color(0xFF2C7A2C);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: o.w, height: o.h), const Radius.circular(10)), _pFill);
    // Cab front (darker)
    _pFill.color = const Color(0xFF1E551E);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y - o.h / 2 + 10), width: o.w - 6, height: 16), const Radius.circular(6)), _pFill);
    // Roof stripe + meter sign
    _pFill.color = const Color(0xFF67B96A);
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y + 4), width: 8, height: o.h - 24), _pFill);
    _pFill.color = const Color(0xFFFFDD00);
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y - o.h / 2 + 4), width: 10, height: 4), _pFill);
  }

  static const _busColors = [Color(0xFFB3282D), Color(0xFF2D6CB3), Color(0xFF2DB35A), Color(0xFFB3902D)];

  void _drawBus(Canvas canvas, Obstacle o) {
    final x = o.x, y = o.y;
    final c = _busColors[o.seed % _busColors.length];
    _pFill.color = c;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: o.w, height: o.h), const Radius.circular(8)), _pFill);
    // Windshield
    _pFill.color = const Color(0xFF101820).withValues(alpha: 0.85);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y - o.h / 2 + 12), width: o.w - 10, height: 14), const Radius.circular(4)), _pFill);
    // Roof — battle scars of a Dhaka local bus
    _pFill.color = Colors.white.withValues(alpha: 0.18);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y + 8), width: o.w - 18, height: o.h - 46), const Radius.circular(5)), _pFill);
    _pStr..color = Colors.black.withValues(alpha: 0.25)..strokeWidth = 2;
    for (int i = 0; i < 3; i++) {
      final ly = y - o.h / 2 + 34 + i * 28.0;
      canvas.drawLine(Offset(x - o.w / 2 + 8, ly), Offset(x + o.w / 2 - 8, ly), _pStr);
    }
  }

  void _drawDog(Canvas canvas, Obstacle o) {
    canvas.save();
    canvas.translate(o.x, o.y);
    if (o.vx > 0) canvas.scale(-1, 1); // 🐕 faces left; flip when running right
    final hop = sin(t * 14 + o.seed) * 2.0;
    _drawEmoji(canvas, '🐕', 0, hop, 24);
    canvas.restore();
    if (o.fleeing) _drawEmoji(canvas, '💨', o.x - o.vx.sign * 18, o.y, 14);
  }

  void _drawSergeant(Canvas canvas, Sergeant s) {
    const r = 13.0;
    final bob = sin(t * 3 + s.x) * 1.5;
    final y = s.y + bob;
    // Body
    _pFill.color = const Color(0xFF3D5A23);
    canvas.drawCircle(Offset(s.x, y), r, _pFill);
    // Cap
    _pFill.color = const Color(0xFF2A3F18);
    canvas.drawRect(Rect.fromCenter(center: Offset(s.x, y - r * 0.8), width: r * 1.5, height: 5), _pFill);
    // Face
    _drawEmoji(canvas, s.staggerT > 0 ? '😵' : '😠', s.x, y + 1, 15);
    // Throwing arm wind-up
    if (s.staggerT <= 0) {
      _pStr..color = const Color(0xFF3D5A23)..strokeWidth = 3..strokeCap = StrokeCap.round;
      final wind = sin(t * 5 + s.x) * 3;
      canvas.drawLine(Offset(s.x + s.side * -r * 0.7, y),
          Offset(s.x + s.side * -r * 1.5, y - 6 + wind), _pStr);
    }
  }

  void _drawPolice(Canvas canvas) {
    final pc = engine.police;
    if (pc == null || !pc.active) return;
    final x = pc.x, y = pc.y;
    // Siren glow
    final flash = (t * 6).toInt() % 2 == 0;
    _pFill.color = (flash ? Colors.red : Colors.blue).withValues(alpha: 0.22);
    canvas.drawCircle(Offset(x, y - 20), 34, _pFill);
    // Body
    _pFill.color = const Color(0xFF13205C);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 44, height: 80), const Radius.circular(8)), _pFill);
    // White doors band
    _pFill.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y + 6), width: 44, height: 12), _pFill);
    // Windshield
    _pFill.color = const Color(0xFF0A1020);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y - 26), width: 36, height: 12), const Radius.circular(3)), _pFill);
    // Light bar
    _pFill.color = flash ? Colors.red : Colors.blue;
    canvas.drawRect(Rect.fromCenter(center: Offset(x - 8, y - 16), width: 12, height: 6), _pFill);
    _pFill.color = flash ? Colors.blue : Colors.red;
    canvas.drawRect(Rect.fromCenter(center: Offset(x + 8, y - 16), width: 12, height: 6), _pFill);
  }

  // ── Mamlas ────────────────────────────────────────────────────────────────────

  void _drawMamlas(Canvas canvas) {
    for (final m in engine.mamlas) {
      if (!m.active) continue;
      canvas.save();
      canvas.translate(m.x, m.y);
      canvas.rotate(m.angle);
      _pFill.color = const Color(0xFFF5F0E0);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: kMamlaW, height: kMamlaH),
          const Radius.circular(2)), _pFill);
      _pFill.color = const Color(0xFF2244AA).withValues(alpha: 0.6);
      for (int i = 0; i < 4; i++) {
        canvas.drawRect(Rect.fromLTWH(-8, -9.0 + i * 5, 16, 1.5), _pFill);
      }
      _pFill.color = Colors.red.withValues(alpha: 0.7);
      canvas.drawCircle(const Offset(5, 7), 4, _pFill);
      _drawText(canvas, '!', 5, 7, 7, Colors.white);
      canvas.restore();
    }
  }

  // ── Fare markers & pickups ────────────────────────────────────────────────────

  void _drawMarkers(Canvas canvas) {
    for (final m in [engine.pickupMarker, engine.dropMarker]) {
      if (m == null || !m.active) continue;
      final c = m.dropoff ? Colors.orange : Colors.greenAccent;
      final pulse = 0.8 + 0.2 * sin(t * 5);
      _pFill.color = c.withValues(alpha: 0.16 * pulse);
      canvas.drawCircle(Offset(m.x, m.y), kMarkerSize * pulse, _pFill);
      _pStr..color = c.withValues(alpha: 0.8)..strokeWidth = 3;
      canvas.drawCircle(Offset(m.x, m.y), kMarkerSize * 0.72, _pStr);
      _drawEmoji(canvas, m.dropoff ? '📍' : '🙋', m.x, m.y - 2, 26);
      final bob = sin(t * 6) * 4;
      _drawText(canvas, '▼', m.x, m.y - kMarkerSize - 12 + bob, 16, c);
    }
  }

  void _drawPickups(Canvas canvas) {
    for (final p in engine.pickups) {
      if (!p.active) continue;
      final bounce = sin(t * 5 + p.x) * 3;
      _pFill.color = Colors.cyan.withValues(alpha: 0.2 + 0.08 * sin(t * 6));
      canvas.drawCircle(Offset(p.x, p.y + bounce), 17, _pFill);
      _drawEmoji(canvas, p.emoji, p.x, p.y + bounce, 22);
    }
  }

  // ── The bike ──────────────────────────────────────────────────────────────────

  void _drawBike(Canvas canvas) {
    final e = engine;
    final x = e.bikeX, y = e.bikeY;
    final lean = e.movLeft ? -0.14 : e.movRight ? 0.14 : 0.0;
    final tier = SaveData.engine.clamp(0, _tierColors.length - 1);

    // Headlight beam
    _pFill.color = const Color(0xFFFFF3B0).withValues(alpha: 0.10);
    final beam = Path()
      ..moveTo(x - 8, y - 26)
      ..lineTo(x - 26, y - 150)
      ..lineTo(x + 26, y - 150)
      ..lineTo(x + 8, y - 26)
      ..close();
    canvas.drawPath(beam, _pFill);

    // Viral rush aura
    if (e.rushT > 0) {
      _pFill.color = Colors.orange.withValues(alpha: 0.18 + 0.1 * sin(t * 10));
      canvas.drawCircle(Offset(x, y), 44, _pFill);
    }

    // Honk shockwave ring
    if (e.honkFx > 0) {
      final p = 1 - e.honkFx; // 0 → 1
      _pStr
        ..color = Colors.yellowAccent.withValues(alpha: 0.5 * e.honkFx)
        ..strokeWidth = 3;
      canvas.drawCircle(Offset(x, y), e.honkRadius * (0.3 + 0.7 * p), _pStr);
    }

    // Invincibility blink
    if (e.invincT > 0 && (t * 8).toInt() % 2 == 0) return;

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(lean);

    // Wheels (top-down: front above, rear below)
    _pFill.color = const Color(0xFF15161A);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -22), width: 9, height: 18), const Radius.circular(4)), _pFill);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 20), width: 10, height: 20), const Radius.circular(4)), _pFill);

    // Frame + tank (tier colour = visible progression)
    _pFill.color = _tierColors[tier];
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -4), width: 16, height: 34), const Radius.circular(6)), _pFill);
    // Tank shine
    _pFill.color = Colors.white.withValues(alpha: tier >= 4 ? 0.45 : 0.2);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-3, -8), width: 4, height: 14), const Radius.circular(2)), _pFill);

    // Handlebars
    _pStr..color = const Color(0xFF999999)..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-11, -16), const Offset(11, -16), _pStr);

    // Passenger (behind the rider) — helmet colour pops
    if (e.carrying) {
      _pFill.color = const Color(0xFFF2C14E);
      canvas.drawCircle(const Offset(0, 9), 7, _pFill);
      _pFill.color = Colors.black.withValues(alpha: 0.25);
      canvas.drawCircle(const Offset(0, 9), 3, _pFill);
    }

    // Rider helmet
    _pFill.color = const Color(0xFFFF4400);
    canvas.drawCircle(const Offset(0, -3), 8, _pFill);
    _pFill.color = const Color(0xFFAACCFF).withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, -7), width: 10, height: 4), _pFill);

    canvas.restore();

    // Exhaust puffs
    if (e.speed > 40) {
      for (int i = 0; i < 3; i++) {
        final alpha = (0.28 - i * 0.08).clamp(0.0, 1.0);
        _pFill.color = Colors.grey.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x + lean * 30, y + 32 + i * 9.0), 3.0 + i * 1.6, _pFill);
      }
    }

    // Speed streaks during viral rush
    if (e.rushT > 0) {
      _pStr..color = Colors.white.withValues(alpha: 0.25)..strokeWidth = 2;
      for (int i = 0; i < 6; i++) {
        final sx = engine.roadL + _rng.nextDouble() * (engine.roadR - engine.roadL);
        final sy = _rng.nextDouble() * e.sh;
        canvas.drawLine(Offset(sx, sy), Offset(sx, sy + 30), _pStr);
      }
    }
  }

  // ── FX ────────────────────────────────────────────────────────────────────────

  void _drawExplosions(Canvas canvas) {
    for (final ex in engine.explosions) {
      final alpha = (1.0 - ex.progress).clamp(0.0, 1.0);
      for (final part in ex.particles) {
        _pFill.color = part.color.withValues(alpha: alpha);
        canvas.drawCircle(Offset(ex.ox + part.x, ex.oy + part.y), part.r * (1 - ex.progress * 0.5), _pFill);
      }
      if (ex.label.isNotEmpty && alpha > 0.3) {
        _drawText(canvas, ex.label, ex.ox, ex.oy - 20 - ex.progress * 30, 13,
            Colors.white.withValues(alpha: alpha));
      }
    }
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final ft in engine.floats) {
      _drawText(canvas, ft.text, ft.x.clamp(70, engine.sw - 70), ft.y, 13,
          ft.color.withValues(alpha: ft.opacity.clamp(0, 1)));
    }
  }

  // ── HUD ───────────────────────────────────────────────────────────────────────

  void _drawHUD(Canvas canvas, Size size) {
    final e = engine;
    final pad = e.topPad;

    _pFill.color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 56 + pad), _pFill);

    // Today's earnings
    final earned = e.dayEarnings.round();
    _drawText(canvas, 'TODAY', 10, pad + 8, 9, Colors.white54, align: TextAlign.left);
    _drawText(canvas, '৳$earned', 10, pad + 21, 18,
        earned >= 0 ? Colors.greenAccent : Colors.redAccent, align: TextAlign.left);

    // Fare status (centre)
    String status;
    Color sc;
    if (e.carrying) {
      status = '📍 ${e.dropRemainM.round()} m';
      sc = Colors.orangeAccent;
    } else if (e.pickupMarker != null) {
      status = '🙋 PICKUP AHEAD';
      sc = Colors.greenAccent;
    } else {
      status = 'find a fare…';
      sc = Colors.white38;
    }
    _drawText(canvas, status, size.width / 2, pad + 14, 14, sc);

    // Best day
    _drawText(canvas, 'BEST', size.width - 10, pad + 8, 9, Colors.white54, align: TextAlign.right);
    _drawText(canvas, '৳${SaveData.bestDay}', size.width - 10, pad + 21, 14, Colors.white54,
        align: TextAlign.right);

    // Row 2: HP bar, mood, wanted, combo, speed
    final y2 = pad + 42.0;
    // HP
    _pFill.color = Colors.white12;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(10, y2, 74, 8), const Radius.circular(4)), _pFill);
    final hpFrac = (e.hp / kMaxHp).clamp(0.0, 1.0);
    _pFill.color = hpFrac > 0.5 ? Colors.greenAccent
        : hpFrac > 0.25 ? Colors.orange : Colors.redAccent;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(10, y2, 74 * hpFrac, 8), const Radius.circular(4)), _pFill);
    _drawText(canvas, '🔧', 94, y2 + 4, 10, Colors.white54);

    // Passenger mood
    if (e.carrying) {
      final face = e.mood >= 4.5 ? '😁' : e.mood >= 3.5 ? '🙂'
          : e.mood >= 2.5 ? '😐' : e.mood >= 1.5 ? '😤' : '😡';
      _drawEmoji(canvas, face, size.width / 2 - 40, y2 + 4, 16);
      _pFill.color = Colors.white12;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width / 2 - 28, y2, 56, 8), const Radius.circular(4)), _pFill);
      _pFill.color = Colors.amber;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width / 2 - 28, y2, 56 * ((e.mood - 1) / 4), 8), const Radius.circular(4)), _pFill);
    } else if (e.combo >= 2) {
      _drawText(canvas, '🔥 ×${e.combo}', size.width / 2, y2 + 4, 13, Colors.orangeAccent);
    }

    // Wanted stars
    if (e.wanted > 0) {
      final pulse = 0.6 + 0.4 * sin(t * 8);
      _drawText(canvas, '🚨${"★" * e.wanted}', size.width - 10, y2 + 4, 13,
          Colors.redAccent.withValues(alpha: pulse), align: TextAlign.right);
    } else {
      _drawText(canvas, '${e.speedKmh.round()} km/h', size.width - 10, y2 + 4, 11,
          Colors.white38, align: TextAlign.right);
    }

    // Viral charge bar
    const barH = 6.0;
    final barW = size.width * 0.5;
    final barX = (size.width - barW) / 2;
    final barY = pad + 58.0;
    _pFill.color = Colors.white12;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(3)), _pFill);
    if (e.viralCharge > 0) {
      final charged = e.viralCharge >= 1.0;
      _pFill.color = charged ? Colors.orange : Colors.orange.withValues(alpha: 0.55);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW * e.viralCharge, barH), const Radius.circular(3)), _pFill);
      if (charged) {
        _drawText(canvas, '🔥 VIRAL READY – swipe up!', size.width / 2, barY + barH + 9, 10,
            Colors.orange.withValues(alpha: 0.8 + 0.2 * sin(t * 6)));
      }
    }
  }

  // ── Overlays ──────────────────────────────────────────────────────────────────

  void _drawGetReady(Canvas canvas, Size size) {
    final n = engine.readyT.ceil().clamp(1, 9);
    final frac = engine.readyT - engine.readyT.floorToDouble();
    _drawText(canvas, '🏍️ SHIFT STARTING', size.width / 2, size.height * 0.36, 20, Colors.yellowAccent);
    _drawText(canvas, '$n', size.width / 2, size.height * 0.45,
        (30 + 14 * frac).roundToDouble(), Colors.white.withValues(alpha: 0.35 + 0.65 * frac));
    _drawText(canvas, 'pick up 🙋  →  drop at 📍  •  HONK 📣 clears the way',
        size.width / 2, size.height * 0.54, 11, Colors.white54);
  }

  void _drawKaput(Canvas canvas, Size size) {
    _pFill.color = Colors.black.withValues(alpha: 0.45);
    canvas.drawRect(Offset.zero & size, _pFill);
    _drawText(canvas, '💥 BIKE KAPUT!', size.width / 2, size.height * 0.44, 24, Colors.redAccent);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _drawEmoji(Canvas canvas, String emoji, double cx, double cy, double size,
      {double opacity = 1.0}) {
    if (size <= 0 || opacity <= 0) return;
    final tp = _tp(emoji, size, Colors.white, emoji: true);
    final offset = Offset(cx - tp.width / 2, cy - tp.height / 2);
    if (opacity < 1.0) {
      final bounds = offset & Size(tp.width, tp.height);
      canvas.saveLayer(bounds, Paint()..color = Colors.white.withValues(alpha: opacity));
      tp.paint(canvas, offset);
      canvas.restore();
    } else {
      tp.paint(canvas, offset);
    }
  }

  void _drawText(Canvas canvas, String text, double cx, double cy, double fontSize, Color color,
      {TextAlign align = TextAlign.center}) {
    final tp = _tp(text, fontSize, color);
    final ox = align == TextAlign.left ? cx : align == TextAlign.right ? cx - tp.width : cx - tp.width / 2;
    tp.paint(canvas, Offset(ox, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(GamePainter old) => true;
}
