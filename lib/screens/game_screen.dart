import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../game/game_painter.dart';
import '../game/entities.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameEngine _engine;
  late AnimationController _animCtrl;
  bool _started = false;

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
    if (_engine.phase == GamePhase.gameOver && mounted) {
      // Small delay so the last frame renders
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => GameOverScreen(engine: _engine)));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // Start engine once we know the screen size
          if (!_started && w > 0 && h > 0) {
            _started = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _engine.start(this, w, h);
            });
          }

          return GestureDetector(
            // Left / Right movement zones
            onPanStart: (d)  => _handleTouch(d.localPosition, w, true),
            onPanUpdate: (d) => _handleTouch(d.localPosition, w, true),
            onPanEnd:   (_)  { _engine.onLeft(false); _engine.onRight(false); },
            onPanCancel: ()  { _engine.onLeft(false); _engine.onRight(false); },
            // Tap = viral blast (swipe up gesture)
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -400) _engine.viralBlast();
            },
            child: Stack(children: [
              // Game canvas
              AnimatedBuilder(
                animation: _animCtrl,
                builder: (_, __) => CustomPaint(
                  painter: GamePainter(_engine, _animCtrl.value * 3600),
                  size: Size(w, h),
                ),
              ),
              // Touch zone indicators (semi-transparent)
              Positioned(
                bottom: 0, left: 0,
                child: _ControlHint(icon: '◀', label: 'LEFT', w: w * 0.42, h: 110),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: _ControlHint(icon: '▶', label: 'RIGHT', w: w * 0.42, h: 110),
              ),
              Positioned(
                bottom: 0,
                left: w * 0.42,
                width: w * 0.16,
                height: 110,
                child: _ViralHint(engine: _engine),
              ),
            ]),
          );
        },
      ),
    );
  }

  void _handleTouch(Offset pos, double w, bool pressing) {
    final leftZone  = pos.dx < w * 0.42;
    final rightZone = pos.dx > w * 0.58;
    _engine.onLeft(pressing && leftZone);
    _engine.onRight(pressing && rightZone);
  }
}

// ── Left / Right zone hint ────────────────────────────────────────────────────
class _ControlHint extends StatelessWidget {
  final String icon, label;
  final double w, h;
  const _ControlHint({required this.icon, required this.label, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white.withOpacity(0.04)],
        ),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 28)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 9, letterSpacing: 2)),
        ],
      ),
    );
  }
}

// ── Viral blast centre hint ───────────────────────────────────────────────────
class _ViralHint extends StatelessWidget {
  final GameEngine engine;
  const _ViralHint({required this.engine});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (_, __) {
        final ready = engine.viralCharge >= 1.0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(ready ? '🔥' : '○', style: TextStyle(
              fontSize: ready ? 28 : 14,
              color: ready ? Colors.orange : Colors.white24)),
            Text('VIRAL', style: TextStyle(
              color: ready ? Colors.orange.withOpacity(0.8) : Colors.white12,
              fontSize: 8, letterSpacing: 1.5,
              fontWeight: FontWeight.w700)),
            Text('↑ swipe', style: TextStyle(
              color: ready ? Colors.orange.withOpacity(0.6) : Colors.white12,
              fontSize: 7)),
          ],
        );
      },
    );
  }
}
