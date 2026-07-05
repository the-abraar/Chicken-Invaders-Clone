import 'dart:math';
import 'package:flutter/material.dart';
import '../game/save_data.dart';
import 'game_screen.dart';
import 'garage_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, _) {
          final t = _ctrl.value * 12;
          return Stack(children: [
            CustomPaint(painter: _StarsPainter(t), size: Size.infinite),
            // Rush-hour banner
            Positioned(
              top: 128,
              left: 0, right: 0,
              child: _TrafficBanner(t: t),
            ),
            // Title
            Positioned(
              top: 56,
              left: 0, right: 0,
              child: Column(children: [
                Text('TRAFFIC', style: TextStyle(
                  fontSize: 44, fontWeight: FontWeight.w900,
                  color: Colors.yellowAccent,
                  letterSpacing: 6,
                  shadows: [
                    Shadow(blurRadius: 20, color: Colors.orange.withValues(alpha: 0.8)),
                    Shadow(blurRadius: 40, color: Colors.red.withValues(alpha: 0.4)),
                  ],
                )),
                Text('TYRANTS', style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 9,
                  shadows: [Shadow(blurRadius: 12, color: Colors.blue.withValues(alpha: 0.6))],
                )),
              ]),
            ),
            // Subtitle
            Positioned(
              top: 258,
              left: 24, right: 24,
              child: Text(
                'Old Dhaka. Night shift. One crappy bike.\nHustle fares, dodge the chaos, honk at the tyrants — and upgrade your way to the top.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.6),
              ),
            ),
            // Buttons
            Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 150),
                _MenuBtn(
                  icon: '🏍️', label: 'START SHIFT',
                  color1: Colors.orange.shade700, color2: Colors.red.shade700,
                  onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const GameScreen())),
                ),
                const SizedBox(height: 14),
                _MenuBtn(
                  icon: '🔧', label: 'GARAGE',
                  color1: Colors.blueGrey.shade700, color2: Colors.blueGrey.shade900,
                  onTap: () async {
                    await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GarageScreen()));
                    if (mounted) setState(() {}); // wallet may have changed
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '💰 ৳${SaveData.wallet}   •   🏆 best day ৳${SaveData.bestDay}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            )),
            // Legend
            const Positioned(
              bottom: 78, left: 0, right: 0,
              child: Column(children: [
                Text('🙋 pick up  →  📍 drop off  =  ৳ paisa', style: TextStyle(color: Colors.white54, fontSize: 12)),
                SizedBox(height: 6),
                Text('🛺 🚌 🐕 🕳️  hurt your bike  •  😠 sergeants throw mamlas', style: TextStyle(color: Colors.white54, fontSize: 11)),
                SizedBox(height: 6),
                Text('📣 HONK scatters everything • swipe UP to go VIRAL 🔥', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
              ]),
            ),
            // Controls hint
            const Positioned(
              bottom: 34, left: 0, right: 0,
              child: Text(
                'Hold LEFT / RIGHT sides to steer • tap 📣 to honk',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            // Studio credit
            const Positioned(
              bottom: 10, left: 0, right: 0,
              child: Text(
                'a BlankFrame Technologies game',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 9, letterSpacing: 1.2),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Menu button ───────────────────────────────────────────────────────────────
class _MenuBtn extends StatelessWidget {
  final String icon, label;
  final Color color1, color2;
  final VoidCallback onTap;
  const _MenuBtn({required this.icon, required this.label,
      required this.color1, required this.color2, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color1, color2]),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: color1.withValues(alpha: 0.4), blurRadius: 22, spreadRadius: 2)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
      ]),
    ),
  );
}

// ── Rush-hour banner ──────────────────────────────────────────────────────────
class _TrafficBanner extends StatelessWidget {
  final double t;
  const _TrafficBanner({required this.t});
  static const _traffic = ['🛺', '🚌', '🐕', '🏍️', '🛺', '😠', '🚔'];
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Stack(clipBehavior: Clip.none, children: [
        for (int i = 0; i < _traffic.length; i++)
          Positioned(
            left: ((i * 52.0 - t * 30) % (_traffic.length * 52.0 + 52) - 52),
            top: 2 + sin(t * 2.5 + i) * 4,
            child: Text(_traffic[i], style: const TextStyle(fontSize: 30)),
          ),
      ]),
    );
  }
}

// ── Starfield ────────────────────────────────────────────────────────────────
class _StarsPainter extends CustomPainter {
  final double t;
  _StarsPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    final p = Paint();
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF060612));
    for (int i = 0; i < 90; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final tw = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * (0.8 + i * 0.13) + i));
      p.color = Colors.white.withValues(alpha: tw * 0.6);
      canvas.drawCircle(Offset(x, y), 0.4 + rng.nextDouble() * 1.2, p);
    }
  }
  @override bool shouldRepaint(_StarsPainter old) => true;
}
