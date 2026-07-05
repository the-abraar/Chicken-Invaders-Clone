import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../game/save_data.dart';
import 'garage_screen.dart';
import 'menu_screen.dart';
import 'game_screen.dart';

/// End-of-shift summary. The engine has already banked the day's earnings
/// into SaveData before this screen appears.
class GameOverScreen extends StatefulWidget {
  final GameEngine engine;
  const GameOverScreen({super.key, required this.engine});
  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // The engine passed here is already disposed (GameScreen owns its
    // lifecycle); we only read its final numbers.
    final e = widget.engine;
    final earned = e.dayEarnings.round();
    final isBest = e.newBest;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fade,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A0015), Color(0xFF150008), Color(0xFF050010)],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔩', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                Text(
                  isBest ? '🏆 BEST SHIFT EVER!' : 'BIKE KAPUT!',
                  style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900,
                    color: isBest ? Colors.yellowAccent : Colors.redAccent,
                    letterSpacing: 3,
                    shadows: [Shadow(blurRadius: 20,
                        color: isBest ? Colors.orange : Colors.red)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The night shift chewed up another bike.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                ),
                const SizedBox(height: 32),

                // Shift report
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(children: [
                    _Row('EARNED', '৳$earned',
                        earned >= 0 ? Colors.greenAccent : Colors.redAccent),
                    const Divider(color: Colors.white12, height: 18),
                    _Row('FARES', '${e.fares}', Colors.cyanAccent),
                    const Divider(color: Colors.white12, height: 18),
                    _Row('DISTANCE', '${(e.distanceM / 1000).toStringAsFixed(1)} km', Colors.white70),
                    const Divider(color: Colors.white12, height: 18),
                    _Row('WALLET', '৳${SaveData.wallet}', Colors.yellowAccent),
                  ]),
                ),
                const SizedBox(height: 36),

                _BigBtn(
                  label: '🏍️  RIDE AGAIN',
                  color1: Colors.orange.shade700,
                  color2: Colors.red.shade700,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const GameScreen())),
                ),
                const SizedBox(height: 12),
                _BigBtn(
                  label: '🔧  GARAGE',
                  color1: Colors.teal.shade700,
                  color2: Colors.teal.shade900,
                  onTap: () async {
                    await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GarageScreen()));
                    if (mounted) setState(() {}); // wallet display refresh
                  },
                ),
                const SizedBox(height: 12),
                _BigBtn(
                  label: '🏠  MAIN MENU',
                  color1: Colors.blueGrey.shade700,
                  color2: Colors.blueGrey.shade900,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MenuScreen())),
                ),
                const SizedBox(height: 24),
                Text(
                  '"Roads break bikes.\nBikes don\'t break riders."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Row(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1.5)),
      Text(value,  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
    ],
  );
}

class _BigBtn extends StatelessWidget {
  final String label;
  final Color color1, color2;
  final VoidCallback onTap;
  const _BigBtn({required this.label, required this.color1, required this.color2, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color1, color2]),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [BoxShadow(color: color1.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 1)],
        ),
        child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: Colors.white, letterSpacing: 1.5)),
      ),
    ),
  );
}
