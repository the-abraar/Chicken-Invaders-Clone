import 'package:shared_preferences/shared_preferences.dart';

/// Persistent progression: wallet, upgrade tiers, records.
/// Loaded once in main() before the app starts, saved on purchases and day end.
class SaveData {
  SaveData._();

  static SharedPreferences? _p;

  static int wallet = 0;
  static int bestDay = 0;
  static int totalFares = 0;

  // Upgrade tiers, 0–kTierMax
  static int engine = 0, handling = 0, horn = 0, seat = 0, guards = 0;

  static Future<void> load() async {
    final p = _p = await SharedPreferences.getInstance();
    wallet     = p.getInt('tt_wallet') ?? 0;
    bestDay    = p.getInt('tt_best_day') ?? 0;
    totalFares = p.getInt('tt_total_fares') ?? 0;
    engine     = p.getInt('tt_up_engine') ?? 0;
    handling   = p.getInt('tt_up_handling') ?? 0;
    horn       = p.getInt('tt_up_horn') ?? 0;
    seat       = p.getInt('tt_up_seat') ?? 0;
    guards     = p.getInt('tt_up_guards') ?? 0;
  }

  static Future<void> save() async {
    final p = _p ?? await SharedPreferences.getInstance();
    await p.setInt('tt_wallet', wallet);
    await p.setInt('tt_best_day', bestDay);
    await p.setInt('tt_total_fares', totalFares);
    await p.setInt('tt_up_engine', engine);
    await p.setInt('tt_up_handling', handling);
    await p.setInt('tt_up_horn', horn);
    await p.setInt('tt_up_seat', seat);
    await p.setInt('tt_up_guards', guards);
  }
}
