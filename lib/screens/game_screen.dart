import 'package:flutter/material.dart';
import '../game/audio.dart';
import '../game/game_engine.dart';
import '../game/game_painter.dart';
import '../game/entities.dart';
import 'game_over_screen.dart';
import 'menu_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameEngine _engine;
  late AnimationController _animCtrl;
  bool _started = false;
  bool _navigating = false;

  // Raw pointer tracking (Listener instead of GestureDetector: gesture-arena
  // competition made hold-to-steer unresponsive until the finger dragged).
  final Map<int, Offset> _pointers = {};
  final Map<int, (Offset, Duration)> _downInfo = {};

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(hours: 1))
      ..repeat();
    _engine.addListener(_checkGameOver);
  }

  @override
  void dispose() {
    _engine.removeListener(_checkGameOver);
    _engine.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _checkGameOver() {
    if (_engine.phase == GamePhase.gameOver && mounted && !_navigating) {
      _navigating = true; // schedule navigation exactly once
      // Short delay so the final crash renders
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => GameOverScreen(engine: _engine)));
        }
      });
    }
  }

  void _goToMenu() {
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MenuScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.viewPaddingOf(context).top;

    return PopScope(
      // Back button: first press pauses, second (while paused) exits to menu.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _engine.phase == GamePhase.gameOver) return;
        if (!_engine.paused) {
          _engine.togglePause();
        } else {
          _goToMenu();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          if (!_started && w > 0 && h > 0) {
            _started = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _engine.start(this, w, h, topPad: topPad);
            });
          } else if (_started) {
            _engine.resize(w, h);
          }

          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              _pointers[e.pointer] = e.localPosition;
              _downInfo[e.pointer] = (e.localPosition, e.timeStamp);
              _updateZones(w);
            },
            onPointerMove: (e) {
              _pointers[e.pointer] = e.localPosition;
              _updateZones(w);
            },
            onPointerUp: (e) => _endPointer(e, w, checkSwipe: true),
            onPointerCancel: (e) => _endPointer(e, w),
            child: Stack(children: [
              // Game canvas
              AnimatedBuilder(
                animation: _animCtrl,
                builder: (_, __) => CustomPaint(
                  painter: GamePainter(_engine, _animCtrl.value * 3600),
                  size: Size(w, h),
                ),
              ),
              // Steer zone hints
              Positioned(
                bottom: 0, left: 0,
                child: _SteerHint(icon: '◀', w: w * 0.40, h: 110),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: _SteerHint(icon: '▶', w: w * 0.40, h: 110),
              ),
              // HONK button — the weapon
              Positioned(
                bottom: 22,
                left: w * 0.40, width: w * 0.20,
                child: Center(child: _HonkButton(engine: _engine)),
              ),
              // Pause button
              Positioned(
                top: topPad + 62, right: 4,
                child: IconButton(
                  icon: const Icon(Icons.pause_rounded, color: Colors.white24, size: 26),
                  onPressed: _engine.togglePause,
                ),
              ),
              // Pause overlay
              ListenableBuilder(
                listenable: _engine,
                builder: (_, __) => _engine.paused
                    ? _PauseOverlay(onResume: _engine.togglePause, onMenu: _goToMenu)
                    : const SizedBox.shrink(),
              ),
            ]),
          );
        },
      ),
    ));
  }

  void _endPointer(PointerEvent e, double w, {bool checkSwipe = false}) {
    final down = _downInfo.remove(e.pointer);
    _pointers.remove(e.pointer);
    _updateZones(w);
    // Swipe up = viral rush
    if (checkSwipe && down != null) {
      final dy = down.$1.dy - e.localPosition.dy;
      final ms = (e.timeStamp - down.$2).inMilliseconds;
      if (dy > 70 && ms > 0 && ms < 400) _engine.viralRush();
    }
  }

  void _updateZones(double w) {
    bool left = false, right = false;
    for (final p in _pointers.values) {
      if (p.dx < w * 0.40) left = true;
      if (p.dx > w * 0.60) right = true;
    }
    _engine.onLeft(left);
    _engine.onRight(right);
  }
}

// ── Honk button ───────────────────────────────────────────────────────────────
class _HonkButton extends StatelessWidget {
  final GameEngine engine;
  const _HonkButton({required this.engine});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (_, __) {
        final ready = engine.honkReady;
        final viral = engine.viralReady;
        return GestureDetector(
          onTap: engine.honk,
          child: Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ready
                  ? LinearGradient(colors: viral
                      ? [Colors.orange.shade600, Colors.deepOrange.shade800]
                      : [Colors.yellow.shade700, Colors.orange.shade800])
                  : LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade900]),
              boxShadow: ready
                  ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 2)]
                  : const [],
              border: Border.all(color: Colors.white.withValues(alpha: ready ? 0.35 : 0.1), width: 2),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('📣', style: TextStyle(fontSize: ready ? 26 : 22)),
              Text(viral ? '↑ VIRAL' : 'HONK', style: TextStyle(
                  fontSize: 8, letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: ready ? 0.9 : 0.3))),
            ]),
          ),
        );
      },
    );
  }
}

// ── Steer zone hint ───────────────────────────────────────────────────────────
class _SteerHint extends StatelessWidget {
  final String icon;
  final double w, h;
  const _SteerHint({required this.icon, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white.withValues(alpha: 0.04)],
        ),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Center(
        child: Text(icon, style: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 26)),
      ),
    );
  }
}

// ── Pause overlay ─────────────────────────────────────────────────────────────
class _PauseOverlay extends StatefulWidget {
  final VoidCallback onResume, onMenu;
  const _PauseOverlay({required this.onResume, required this.onMenu});
  @override
  State<_PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<_PauseOverlay> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⏸️', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          const Text('CHA BREAK', style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: 4)),
          const SizedBox(height: 28),
          _PauseBtn(label: '▶  BACK TO WORK', color: Colors.orange.shade700, onTap: widget.onResume),
          const SizedBox(height: 12),
          _PauseBtn(
            label: Sfx.enabled ? '🔊  SOUND ON' : '🔇  SOUND OFF',
            color: Colors.blueGrey.shade700,
            onTap: () => setState(() => Sfx.enabled = !Sfx.enabled),
          ),
          const SizedBox(height: 12),
          _PauseBtn(label: '🏠  CALL IT A DAY', color: Colors.blueGrey.shade800, onTap: widget.onMenu),
        ],
      ),
    );
  }
}

class _PauseBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PauseBtn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 230,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: Colors.white, letterSpacing: 1.2)),
    ),
  );
}
