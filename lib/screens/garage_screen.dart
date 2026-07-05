import 'dart:math';
import 'package:flutter/material.dart';
import '../game/audio.dart';
import '../game/constants.dart';
import '../game/save_data.dart';

/// The garage: spend your hard-earned ৳ on turning the crappy bike
/// into a street legend. Tiers persist between runs.
class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});
  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _Upgrade {
  final String emoji, name, desc;
  final int Function() tier;
  final void Function(int) setTier;
  const _Upgrade(this.emoji, this.name, this.desc, this.tier, this.setTier);
}

class _GarageScreenState extends State<GarageScreen> {
  late final List<_Upgrade> _ups = [
    _Upgrade('⚙️', 'ENGINE', 'Top speed — earn faster',
        () => SaveData.engine, (v) => SaveData.engine = v),
    _Upgrade('🛞', 'HANDLING', 'Sharper steering',
        () => SaveData.handling, (v) => SaveData.handling = v),
    _Upgrade('📣', 'HORN', 'Bigger blast, shorter cooldown',
        () => SaveData.horn, (v) => SaveData.horn = v),
    _Upgrade('💺', 'SEAT', 'Happier passengers, fatter tips',
        () => SaveData.seat, (v) => SaveData.seat = v),
    _Upgrade('🛡️', 'GUARDS', 'Crash bars — take less damage',
        () => SaveData.guards, (v) => SaveData.guards = v),
  ];

  int _cost(int tier) => kUpCostBase * pow(2, tier).toInt();

  void _buy(_Upgrade u) {
    final t = u.tier();
    final c = _cost(t);
    if (t >= kTierMax || SaveData.wallet < c) return;
    setState(() {
      SaveData.wallet -= c;
      u.setTier(t + 1);
    });
    SaveData.save();
    Sfx.ding(); Sfx.tapMedium();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Text('🔧 GARAGE', style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 3)),
              const Spacer(),
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: Text('💰 ৳${SaveData.wallet}', style: const TextStyle(
                    color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Every tier makes the night shift kinder.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: _ups.length,
                itemBuilder: (_, i) => _UpgradeCard(
                  up: _ups[i],
                  cost: _cost(_ups[i].tier()),
                  onBuy: () => _buy(_ups[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final _Upgrade up;
  final int cost;
  final VoidCallback onBuy;
  const _UpgradeCard({required this.up, required this.cost, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final tier = up.tier();
    final maxed = tier >= kTierMax;
    final affordable = !maxed && SaveData.wallet >= cost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: maxed ? Colors.amber.withValues(alpha: 0.5) : Colors.white12),
      ),
      child: Row(children: [
        Text(up.emoji, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(up.name, style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 2),
            Text(up.desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            const SizedBox(height: 6),
            Row(children: [
              for (int i = 0; i < kTierMax; i++)
                Container(
                  width: 22, height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i < tier ? Colors.orangeAccent : Colors.white12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onBuy,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: maxed
                  ? LinearGradient(colors: [Colors.amber.shade700, Colors.amber.shade900])
                  : affordable
                      ? LinearGradient(colors: [Colors.orange.shade700, Colors.red.shade700])
                      : LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade900]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              maxed ? 'MAX ★' : '৳$cost',
              style: TextStyle(
                color: maxed ? Colors.black : affordable ? Colors.white : Colors.white38,
                fontSize: 14, fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
