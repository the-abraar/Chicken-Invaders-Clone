import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'audio.dart';
import 'constants.dart';
import 'entities.dart';
import 'save_data.dart';

/// The whole simulation: an endless scrolling Dhaka street.
/// Pick up fares, dodge traffic, honk your way through, get paid.
class GameEngine extends ChangeNotifier {
  // ── Screen ───────────────────────────────────────────────────────────────────
  double sw = 0, sh = 0;
  double topPad = 0;

  double get roadL => sw * kShoulderFrac;
  double get roadR => sw - roadL;
  double get laneW => (roadR - roadL) / kLanes;
  double laneX(int i) => roadL + laneW * (i + 0.5);

  // ── Bike ─────────────────────────────────────────────────────────────────────
  double bikeX = 0;
  double get bikeY => sh - 190;
  double speed = 0;          // current scroll px/s
  double _bounceVx = 0;      // lateral kickback after hitting a bus
  double _slowT = 0;         // pothole / bus slowdown
  double hp = kMaxHp;
  double invincT = 0;

  // Upgrade-derived stats (snapshotted at start())
  double _topSpeed = kSpeedBase, _steer = kSteerBase;
  double honkRadius = kHonkRadiusBase;
  double _honkCdMax = kHonkCdBase;
  int _seatTier = 0, _guardTier = 0;

  // ── World scroll ─────────────────────────────────────────────────────────────
  double worldOffset = 0; // px travelled
  double get distanceM => worldOffset / kPxPerMeter;

  // ── Fare state ───────────────────────────────────────────────────────────────
  bool carrying = false;
  double mood = 5.0;
  double _pickupAtM = 0, dropTargetM = 0;
  FareMarker? pickupMarker, dropMarker;
  double _fareCooldown = 1.0, _dropRespawnT = 0;
  int fares = 0;

  double get dropRemainM => carrying ? max(0, dropTargetM - distanceM) : 0;

  // ── Economy ──────────────────────────────────────────────────────────────────
  double dayEarnings = 0;
  bool newBest = false; // set at day end, read by the shift-report screen

  // ── Combat-ish ───────────────────────────────────────────────────────────────
  double honkCD = 0, honkFx = 0;
  double viralCharge = 0, rushT = 0;
  int combo = 0;
  double _comboT = 0;
  int wanted = 0;
  double _wantedT = 0;

  bool get honkReady  => honkCD <= 0;
  bool get viralReady => viralCharge >= 1.0;
  bool get isProtected => invincT > 0 || rushT > 0;
  double get speedKmh => speed / kPxPerMeter * 3.6;

  // ── Entities ─────────────────────────────────────────────────────────────────
  final List<Obstacle>   obstacles  = [];
  final List<Sergeant>   sergeants  = [];
  final List<Mamla>      mamlas     = [];
  final List<RoadPickup> pickups    = [];
  final List<Explosion>  explosions = [];
  final List<FloatingText> floats   = [];
  PoliceCar? police;

  // ── Input ────────────────────────────────────────────────────────────────────
  bool movLeft = false, movRight = false;

  // ── Phase / timing ───────────────────────────────────────────────────────────
  GamePhase phase = GamePhase.getReady;
  bool paused = false;
  double _readyT = 0, _shakeT = 0;
  double _spawnT = 1.0, _sergeantT = 4.0, _pickupT = 6.0;

  double get readyT => _readyT;
  double get shake  => _shakeT.clamp(0, 1);

  GamePhase _prevPhase = GamePhase.getReady;
  bool _prevViral = false, _prevHonk = true;
  bool _disposed = false;

  // ── Ticker ───────────────────────────────────────────────────────────────────
  Ticker? _ticker;
  Duration? _last;
  final _rng = Random();

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  void start(TickerProvider vsync, double w, double h, {double topPad = 0}) {
    this.topPad = topPad;
    sw = w; sh = h;
    bikeX = sw / 2;

    // Snapshot upgrade stats for this run.
    _topSpeed   = kSpeedBase + SaveData.engine * kSpeedPerTier;
    _steer      = kSteerBase + SaveData.handling * kSteerPerTier;
    honkRadius  = kHonkRadiusBase + SaveData.horn * kHonkRadiusTier;
    _honkCdMax  = kHonkCdBase - SaveData.horn * kHonkCdTier;
    _seatTier   = SaveData.seat;
    _guardTier  = SaveData.guards;

    _reset();
    _ticker?.dispose();
    _last = null;
    _ticker = vsync.createTicker(_tick)..start();
  }

  void resize(double w, double h) {
    if (w == sw && h == sh) return;
    sw = w; sh = h;
    bikeX = bikeX.clamp(roadL, roadR);
  }

  @override
  void dispose() { _disposed = true; _ticker?.dispose(); super.dispose(); }

  void onLeft(bool v)  => movLeft  = v;
  void onRight(bool v) => movRight = v;

  void togglePause() {
    if (phase == GamePhase.gameOver) return;
    paused = !paused;
    notifyListeners();
  }

  void _reset() {
    obstacles.clear(); sergeants.clear(); mamlas.clear();
    pickups.clear(); explosions.clear(); floats.clear();
    police = null;
    pickupMarker = null; dropMarker = null;
    carrying = false; mood = 5.0; fares = 0;
    dayEarnings = 0; newBest = false; hp = kMaxHp;
    speed = 0; worldOffset = 0;
    combo = 0; _comboT = 0; viralCharge = 0; rushT = 0;
    wanted = 0; _wantedT = 0;
    honkCD = 0; honkFx = 0;
    invincT = 0; _slowT = 0; _bounceVx = 0;
    _spawnT = 1.2; _sergeantT = 5.0; _pickupT = 6.0; _fareCooldown = 1.0;
    _dropRespawnT = 0;
    _shakeT = 0;
    phase = GamePhase.getReady;
    _readyT = kGetReadyDuration;
  }

  // ── Player actions ───────────────────────────────────────────────────────────

  /// The honk IS the weapon: knocks mamlas out of the air, scatters dogs,
  /// shoves rickshaws aside and makes sergeants flinch.
  void honk() {
    if (paused || phase != GamePhase.riding || honkCD > 0) return;
    honkCD = _honkCdMax;
    honkFx = 1.0;
    Sfx.honk(); Sfx.tapLight();

    final r = honkRadius;
    for (final m in mamlas) {
      if (!m.active) continue;
      if (_dist(m.x, m.y) < r) {
        m.active = false;
        combo++; _comboT = 4.0;
        viralCharge = (viralCharge + kViralPerMamla).clamp(0, 1);
        explosions.add(Explosion(ox: m.x, oy: m.y));
        _addFloat(m.x, m.y - 14, 'DISMISSED!', Colors.orangeAccent);
      }
    }
    for (final o in obstacles) {
      if (!o.active || _dist(o.x, o.y) > r) continue;
      switch (o.type) {
        case ObstacleType.dog:
          o.fleeing = true;
          o.vx = (o.x < bikeX ? -1 : 1) * (kDogCrossVx * 2.2);
          o.ownSpeed = -90; // scampers off behind you
        case ObstacleType.rickshaw:
          o.vx = (o.x >= bikeX ? 1 : -1) * 175.0;
        case ObstacleType.cng:
          o.vx += (o.x >= bikeX ? 1 : -1) * 60.0;
        default: // buses and potholes don't care about your horn
          break;
      }
    }
    for (final s in sergeants) {
      if (s.active && _dist(s.x, s.y) < r * 1.2) {
        s.staggerT = kSergeantStagger;
        _addFloat(s.x, s.y - 24, '😳', Colors.white);
      }
    }
  }

  /// Swipe up when charged: go viral. Everyone clears the road for the
  /// famous biker — brief invincibility, speed boost, double earnings.
  void viralRush() {
    if (paused || phase != GamePhase.riding || viralCharge < 1.0) return;
    viralCharge = 0;
    rushT = kViralRushTime;
    _shakeT = 0.5;
    Sfx.bigBoom(); Sfx.tapHeavy();
    _addFloat(sw / 2, sh * .4, '🔥 GONE VIRAL! 2× EARNINGS!', Colors.orange);
    // Traffic parts like the Red Sea.
    for (final o in obstacles) {
      if (o.type == ObstacleType.pothole) continue;
      o.vx = (o.x >= sw / 2 ? 1 : -1) * 150.0;
    }
  }

  double _dist(double x, double y) {
    final dx = x - bikeX, dy = y - bikeY;
    return sqrt(dx * dx + dy * dy);
  }

  // ── Tick ─────────────────────────────────────────────────────────────────────

  void _tick(Duration now) {
    double dt = _last == null ? 0 : (now - _last!).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.1) return;
    if (!paused) _update(dt);

    if (phase != _prevPhase || viralReady != _prevViral || honkReady != _prevHonk) {
      _prevPhase = phase; _prevViral = viralReady; _prevHonk = honkReady;
      notifyListeners();
    }
  }

  void _update(double dt) {
    if (phase == GamePhase.gameOver) {
      // Keep the final crash alive: particles fly, texts fade, shake settles.
      _updateFx(dt);
      if (_shakeT > 0) _shakeT -= dt * 2;
      return;
    }

    if (phase == GamePhase.getReady) {
      _readyT -= dt;
      _moveBike(dt);
      _updateFx(dt);
      if (_readyT <= 0) phase = GamePhase.riding;
      return;
    }

    // Speed: ease toward top speed; slowdowns and viral rush modify it.
    final target = _topSpeed
        * (rushT > 0 ? kViralSpeedMult : 1.0)
        * (_slowT > 0 ? 0.5 : 1.0);
    speed += (target - speed) * min(1, dt * 2.2);
    worldOffset += speed * dt;

    _moveBike(dt);
    _spawn(dt);
    _updateObstacles(dt);
    _updateSergeants(dt);
    _updateMamlas(dt);
    _updatePickups(dt);
    _updateFares(dt);
    _updatePolice(dt);
    _updateTimers(dt);
    _updateFx(dt);
    _collide();
  }

  void _moveBike(double dt) {
    if (movLeft)  bikeX -= _steer * dt;
    if (movRight) bikeX += _steer * dt;
    bikeX += _bounceVx * dt;
    _bounceVx -= _bounceVx * min(1, dt * 5);
    bikeX = bikeX.clamp(roadL + kBikeW / 2, roadR - kBikeW / 2);
  }

  // ── Spawning ─────────────────────────────────────────────────────────────────

  void _spawn(double dt) {
    // Traffic — ramps up with distance.
    _spawnT -= dt;
    if (_spawnT <= 0) {
      _spawnT = (1.45 - distanceM / 2500).clamp(0.55, 1.45)
          * (0.7 + _rng.nextDouble() * 0.6);
      _spawnObstacle();
    }

    // Sergeants appear after 150 m.
    _sergeantT -= dt;
    if (_sergeantT <= 0 && distanceM > 150) {
      _sergeantT = 5.5 + _rng.nextDouble() * 4.5;
      final side = _rng.nextBool() ? -1 : 1;
      final x = side < 0 ? roadL * 0.5 : sw - roadL * 0.5;
      sergeants.add(Sergeant(x: x, y: -40, side: side));
    }

    // Roadside goodies.
    _pickupT -= dt;
    if (_pickupT <= 0) {
      _pickupT = 4.5 + _rng.nextDouble() * 4.0;
      final roll = _rng.nextDouble();
      final kind = roll < 0.55 ? PickupKind.cash
                 : roll < 0.80 ? PickupKind.tea
                 : PickupKind.wrench;
      pickups.add(RoadPickup(
        x: laneX(_rng.nextInt(kLanes)),
        y: -40,
        kind: kind,
        value: 40 + _rng.nextInt(9) * 10,
      ));
    }
  }

  void _spawnObstacle() {
    final roll = _rng.nextDouble();
    final type = roll < 0.30 ? ObstacleType.rickshaw
               : roll < 0.54 ? ObstacleType.cng
               : roll < 0.68 ? ObstacleType.pothole
               : roll < 0.84 ? ObstacleType.dog
               : ObstacleType.bus;

    double x, own;
    if (type == ObstacleType.dog) {
      final fromLeft = _rng.nextBool();
      x = fromLeft ? roadL - 20 : roadR + 20;
      final o = Obstacle(type: type, x: x, y: -30, ownSpeed: kDogSpeed, seed: _rng.nextInt(1000));
      o.vx = (fromLeft ? 1 : -1) * kDogCrossVx;
      obstacles.add(o);
      return;
    }
    x = laneX(_rng.nextInt(kLanes)) + (_rng.nextDouble() - 0.5) * laneW * 0.3;
    own = switch (type) {
      ObstacleType.rickshaw => kRickshawSpeed,
      ObstacleType.cng      => kCngSpeed,
      ObstacleType.bus      => kBusSpeed,
      _                     => 0,
    };
    final o = Obstacle(type: type, x: x, y: -80, ownSpeed: own, seed: _rng.nextInt(1000));
    // Don't spawn on top of something already near the top of the screen.
    for (final other in obstacles) {
      if (!other.active || other.y > 160) continue;
      if ((other.x - o.x).abs() < (other.w + o.w) / 2 + 8 &&
          (other.y - o.y).abs() < (other.h + o.h) / 2 + 30) {
        return; // skip this spawn; the timer will try again soon
      }
    }
    obstacles.add(o);
  }

  // ── Entity updates ───────────────────────────────────────────────────────────

  void _updateObstacles(double dt) {
    for (final o in obstacles) {
      if (!o.active) continue;
      o.y += (speed - o.ownSpeed) * dt;
      o.x += o.vx * dt;

      switch (o.type) {
        case ObstacleType.cng:
          o.weaveT += dt * 1.6;
          o.x += sin(o.weaveT) * 30 * dt;
          o.vx -= o.vx * min(1, dt * 2);
        case ObstacleType.rickshaw:
          o.vx -= o.vx * min(1, dt * 2.5); // shove decays
        case ObstacleType.dog:
          if (!o.fleeing &&
              (o.x < roadL - 40 && o.vx < 0 || o.x > roadR + 40 && o.vx > 0)) {
            o.active = false; // crossed the road, lived to bark another day
          }
        default:
          break;
      }
      if (o.type != ObstacleType.dog && o.type != ObstacleType.pothole) {
        o.x = o.x.clamp(roadL - 10, roadR + 10);
      }

      // Near-miss: squeeze past something without touching it.
      if (!o.shaved && !isProtected &&
          (o.y - bikeY).abs() < 18 &&
          o.type != ObstacleType.pothole) {
        final gap = (o.x - bikeX).abs() - (o.w + kBikeW) / 2;
        if (gap > 0 && gap < 30) {
          o.shaved = true;
          combo++; _comboT = 4.0;
          viralCharge = (viralCharge + kViralPerShave).clamp(0, 1);
          if (carrying) mood = (mood + 0.05).clamp(1.0, 5.0); // passengers love a pro
          _addFloat(bikeX, bikeY - 44, 'CLOSE! ×$combo', Colors.cyanAccent);
        }
      }

      if (o.y > sh + 90) o.active = false;
    }
    obstacles.removeWhere((o) => !o.active);
  }

  void _updateSergeants(double dt) {
    for (final s in sergeants) {
      if (!s.active) continue;
      s.y += speed * dt;
      if (s.staggerT > 0) s.staggerT -= dt;
      s.throwT -= dt;
      if (s.throwT <= 0 && s.staggerT <= 0 &&
          s.y > 60 && s.y < bikeY - 120) {
        s.throwT = 1.6 + _rng.nextDouble() * 0.8;
        final vy = kMamlaSpeed + speed * 0.6;
        final tArrive = max(0.35, (bikeY - s.y) / vy);
        final vx = ((bikeX - s.x) / tArrive).clamp(-kMamlaMaxAimVx, kMamlaMaxAimVx);
        mamlas.add(Mamla(x: s.x, y: s.y + 14, vx: vx, vy: vy));
      }
      if (s.y > sh + 60) s.active = false;
    }
    sergeants.removeWhere((s) => !s.active);
  }

  void _updateMamlas(double dt) {
    for (final m in mamlas) {
      if (!m.active) continue;
      m.x += m.vx * dt;
      m.y += m.vy * dt;
      m.angle += m.spin * dt;
      if (m.y > sh + 40 || m.x < -30 || m.x > sw + 30) m.active = false;
    }
    mamlas.removeWhere((m) => !m.active);
  }

  void _updatePickups(double dt) {
    for (final p in pickups) {
      if (!p.active) continue;
      p.y += speed * dt;
      if (p.y > sh + 40) { p.active = false; continue; }
      if ((p.x - bikeX).abs() < 34 && (p.y - bikeY).abs() < 40) {
        p.active = false;
        Sfx.ding(); Sfx.tapLight();
        switch (p.kind) {
          case PickupKind.cash:
            final v = rushT > 0 ? p.value * 2 : p.value;
            dayEarnings += v;
            _addFloat(p.x, p.y - 16, '+৳$v', Colors.greenAccent);
          case PickupKind.tea:
            if (carrying) {
              mood = (mood + 1.2).clamp(1.0, 5.0);
              _addFloat(p.x, p.y - 16, '☕ CHA! mood up', Colors.amber);
            } else {
              dayEarnings += 20;
              _addFloat(p.x, p.y - 16, '☕ +৳20', Colors.amber);
            }
          case PickupKind.wrench:
            hp = (hp + 25).clamp(0, kMaxHp);
            _addFloat(p.x, p.y - 16, '🔧 +25 HP', Colors.lightGreenAccent);
        }
      }
    }
    pickups.removeWhere((p) => !p.active);
  }

  // ── Fares ────────────────────────────────────────────────────────────────────

  void _updateFares(double dt) {
    // Spawn a pickup marker when idle.
    if (!carrying && pickupMarker == null) {
      _fareCooldown -= dt;
      if (_fareCooldown <= 0) {
        pickupMarker = FareMarker(
          x: laneX(_rng.nextInt(kLanes)), y: -60, dropoff: false);
      }
    }

    final pm = pickupMarker;
    if (pm != null) {
      pm.y += speed * dt;
      if (pm.y > sh + 60) {
        pickupMarker = null;
        _fareCooldown = 1.5; // missed them — someone else will flag you down
      } else if ((pm.x - bikeX).abs() < kMarkerSize && (pm.y - bikeY).abs() < kMarkerSize) {
        pickupMarker = null;
        carrying = true;
        mood = 5.0;
        _pickupAtM = distanceM;
        dropTargetM = distanceM + kFareMinM + _rng.nextDouble() * (kFareMaxM - kFareMinM);
        Sfx.ding(); Sfx.tapMedium();
        _addFloat(bikeX, bikeY - 50, '🙋 FARE! drop in ${(dropTargetM - distanceM).round()} m',
            Colors.greenAccent);
      }
    }

    if (carrying) {
      mood = (mood - kMoodDecay * (1 - _seatTier * kSeatMoodPerTier) * dt).clamp(1.0, 5.0);

      // Spawn the dropoff marker when it's due on screen.
      if (dropMarker == null) {
        _dropRespawnT -= dt;
        if (_dropRespawnT <= 0 &&
            (dropTargetM - distanceM) * kPxPerMeter < sh * 0.9) {
          dropMarker = FareMarker(
            x: laneX(_rng.nextInt(kLanes)), y: -60, dropoff: true);
        }
      }

      final dm = dropMarker;
      if (dm != null) {
        dm.y += speed * dt;
        if (dm.y > sh + 60) {
          dropMarker = null;
          _dropRespawnT = 1.2;
          mood = (mood - 0.6).clamp(1.0, 5.0);
          _addFloat(bikeX, bikeY - 50, '😤 MISSED THE DROP!', Colors.redAccent);
        } else if ((dm.x - bikeX).abs() < kMarkerSize && (dm.y - bikeY).abs() < kMarkerSize) {
          dropMarker = null;
          _deliver();
        }
      }
    }
  }

  void _deliver() {
    carrying = false;
    fares++;
    SaveData.totalFares++;
    final dist = dropTargetM - _pickupAtM;
    final moodMult = 0.4 + 0.2 * mood; // 😡 0.6× … 😁 1.4×
    final tip = min(combo, 20) * kTipPerShave;
    double pay = (kFareBase + dist * kFarePerM) * moodMult
        * (1 + _seatTier * kSeatTipPerTier) + tip;
    if (rushT > 0) pay *= 2;
    dayEarnings += pay;
    viralCharge = (viralCharge + kViralPerDeliver).clamp(0, 1);
    _fareCooldown = 2.0;
    Sfx.ding(); Sfx.tapMedium();
    final face = mood >= 4.5 ? '😁' : mood >= 3.5 ? '🙂' : mood >= 2.5 ? '😐' : mood >= 1.5 ? '😤' : '😡';
    _addFloat(bikeX, bikeY - 56, '$face +৳${pay.round()}${rushT > 0 ? " (VIRAL 2×)" : ""}',
        Colors.greenAccent);
  }

  // ── Police ───────────────────────────────────────────────────────────────────

  void _addWanted() {
    wanted = min(kWantedMax, wanted + 1);
    _wantedT = kWantedDecayTime;
    _addFloat(bikeX, bikeY - 66, '🚨 WANTED ${"★" * wanted}', Colors.redAccent);
  }

  void _updatePolice(double dt) {
    if (wanted > 0 && police == null) {
      police = PoliceCar(x: bikeX, y: sh + 140);
    }
    final pc = police;
    if (pc == null) return;

    if (pc.leaving || rushT > 0) {
      pc.y += 200 * dt; // falls behind (viral crowds block the cops too)
      if (pc.y > sh + 200) police = null;
      return;
    }

    // Closes in from behind, mirrors your lane.
    pc.y -= (44 + 26 * wanted) * dt;
    pc.y = max(pc.y, bikeY + 46); // rams your rear wheel, doesn't overtake
    final dx = bikeX - pc.x;
    final chase = (110 + 35 * wanted) * dt;
    pc.x += dx.abs() < chase ? dx : dx.sign * chase;

    if (!isProtected &&
        (pc.x - bikeX).abs() < (kBikeW + 44) / 2 &&
        (pc.y - bikeY).abs() < (kBikeH + 80) / 2) {
      // Caught!
      dayEarnings -= kPoliceFine;
      wanted = 0;
      pc.leaving = true;
      invincT = kInvincibleDuration * 1.5;
      _shakeT = 0.7;
      Sfx.crash(); Sfx.tapHeavy();
      if (carrying) mood = (mood - 1.0).clamp(1.0, 5.0);
      _addFloat(bikeX, bikeY - 56, '🚔 CAUGHT! −৳${kPoliceFine.round()}', Colors.lightBlueAccent);
    }
  }

  // ── Timers / FX ──────────────────────────────────────────────────────────────

  void _updateTimers(double dt) {
    if (honkCD > 0) honkCD -= dt;
    if (honkFx > 0) honkFx -= dt * 2.4;
    if (invincT > 0) invincT -= dt;
    if (_slowT > 0) _slowT -= dt;
    if (rushT > 0) rushT -= dt;
    if (_comboT > 0) { _comboT -= dt; if (_comboT <= 0) combo = 0; }
    if (_shakeT > 0) _shakeT -= dt * 2;
    if (wanted > 0) {
      _wantedT -= dt;
      if (_wantedT <= 0) {
        wanted--;
        _wantedT = kWantedDecayTime;
        if (wanted == 0) police?.leaving = true;
      }
    }
  }

  void _updateFx(double dt) {
    for (final ex in explosions) {
      ex.progress += dt * 1.6;
      for (final p in ex.particles) {
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.vy += 220 * dt;
      }
    }
    explosions.removeWhere((ex) => ex.progress >= 1.0);

    for (final ft in floats) {
      ft.y += ft.vy * dt;
      ft.opacity -= dt * 1.4;
    }
    floats.removeWhere((ft) => ft.opacity <= 0);
  }

  // ── Collisions ───────────────────────────────────────────────────────────────

  void _collide() {
    if (phase != GamePhase.riding) return;

    // Mamlas land on you → fine (paper cuts your wallet, not your bike).
    if (!isProtected) {
      for (final m in mamlas) {
        if (!m.active) continue;
        if (_hit(m.x, m.y, kMamlaW, kMamlaH, bikeX, bikeY, kBikeW, kBikeH)) {
          m.active = false;
          dayEarnings -= kMamlaFine;
          invincT = 0.6;
          _shakeT = 0.35;
          Sfx.crash(); Sfx.tapMedium();
          if (carrying) mood = (mood - 0.5).clamp(1.0, 5.0);
          _addFloat(bikeX, bikeY - 50, '📋 CASE FILED! −৳${kMamlaFine.round()}', Colors.red);
        }
      }
    }

    if (isProtected) return;
    for (final o in obstacles) {
      if (!o.active) continue;
      if (!_hit(o.x, o.y, o.w, o.h, bikeX, bikeY, kBikeW, kBikeH)) continue;

      final dmg = switch (o.type) {
        ObstacleType.bus      => kDmgBus,
        ObstacleType.cng      => kDmgCng,
        ObstacleType.rickshaw => kDmgRickshaw,
        ObstacleType.dog      => kDmgDog,
        ObstacleType.pothole  => kDmgPothole,
      };
      hp -= dmg * (1 - _guardTier * kGuardPerTier);
      invincT = kInvincibleDuration;
      _shakeT = 0.55;
      combo = 0;
      Sfx.crash(); Sfx.tapHeavy();
      if (carrying) mood = (mood - 1.0).clamp(1.0, 5.0);
      explosions.add(Explosion(ox: bikeX, oy: bikeY - 20));

      switch (o.type) {
        case ObstacleType.bus:
          _bounceVx = (bikeX >= o.x ? 1 : -1) * 300.0;
          _slowT = 1.2;
          _addFloat(bikeX, bikeY - 50, '🚌 BUS! OUCH!', Colors.orangeAccent);
        case ObstacleType.pothole:
          _slowT = 0.8;
          _addFloat(bikeX, bikeY - 50, '🕳️ POTHOLE!', Colors.orangeAccent);
        case ObstacleType.dog:
          o.active = false;
          _addFloat(o.x, o.y - 16, '🐕 GHEU!', Colors.yellowAccent);
          _addWanted();
        case ObstacleType.rickshaw:
          o.active = false;
          _addFloat(o.x, o.y - 16, '😡 OI MAMA!', Colors.redAccent);
          _addWanted();
        case ObstacleType.cng:
          o.active = false;
          _addFloat(o.x, o.y - 16, '😡 DEKHE CHALA!', Colors.redAccent);
          _addWanted();
      }

      if (hp <= 0) { _dayOver(); return; }
      break; // one collision per frame is plenty of pain
    }
  }

  bool _hit(double ax, double ay, double aw, double ah,
            double bx, double by, double bw, double bh) =>
      (ax - aw/2 < bx + bw/2) && (ax + aw/2 > bx - bw/2) &&
      (ay - ah/2 < by + bh/2) && (ay + ah/2 > by - bh/2);

  // ── Day over ─────────────────────────────────────────────────────────────────

  void _dayOver() {
    phase = GamePhase.gameOver;
    hp = 0;
    _shakeT = 1.0;
    Sfx.bigBoom(); Sfx.tapHeavy();
    explosions.add(Explosion(ox: bikeX, oy: bikeY));
    final earned = dayEarnings.round();
    SaveData.wallet = max(0, SaveData.wallet + earned);
    newBest = earned > 0 && earned > SaveData.bestDay; // decide BEFORE updating
    if (newBest) SaveData.bestDay = earned;
    SaveData.save();
  }

  void _addFloat(double x, double y, String text, Color c) =>
      floats.add(FloatingText(x: x, y: y, text: text, color: c));
}
