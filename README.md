# 🏍️ Traffic Tyrants

> Old Dhaka. Night shift. One crappy bike. The streets are ruled by traffic tyrants — corrupt sergeants hurling **mamlas** (court cases 📋), kamikaze rickshaws, buses that answer to no god, and dogs with a death wish. Hustle fares, honk your way through, and upgrade your way to the top.

A fast, juicy, emoji-powered **endless ride-share hustle** built entirely with Flutter's Canvas — no game engine, no sprite sheets, just `CustomPainter`, math, and attitude. Designed for phones (Android & iOS), portrait, one-thumb-and-a-honk gameplay.

Built by **BlankFrame Technologies**.

<p align="center">
  <em>🙋 pick up → 📍 drop off → ৳ get paid → 🔧 upgrade → repeat until the bike gives out</em>
</p>

## The loop

You're a night-shift ride-share rider on a rusty two-wheeler. Scoop up passengers (🙋), weave them through traffic to the drop pin (📍), and get paid based on **distance, tips, and mood** — every crash makes your passenger angrier and your payout thinner. Bank your ৳, then spend it in the **garage** between runs. Your bike's paint literally changes as you climb from rust-bucket to gold-plated tyrant of the road.

## Why you'll get hooked

- **📣 The honk is the weapon.** One tap scatters street dogs, shoves rickshaws aside, makes sergeants flinch mid-throw, and knocks flying mamlas clean out of the air ("DISMISSED!").
- **😠 Sergeants line the roadside** and lead their mamla throws at you. Each one that lands is a ৳150 fine — *case filed*.
- **🚨 Wanted stars.** Clip a rickshaw, CNG, or dog and the law takes interest. At any stars, a police car chases you from behind, mirroring your lane. Get caught: ৳300 and your passenger's respect.
- **🔥 Go Viral.** Near-misses and deliveries charge the viral meter. Swipe up and the whole street parts for the famous biker — invincible, faster, and **2× earnings** while it lasts.
- **😁→😡 Passenger mood** is a live meter. Smooth close shaves impress them; crashes, missed drops, and police stops do not. Mood multiplies the fare (0.6×–1.4×). A roadside ☕ fixes a lot.
- **🔧 Persistent garage.** Five upgrade lines — Engine, Handling, Horn, Seat, Guards — each 5 tiers, each visibly changing how the game feels (and how the bike looks).
- **Feel.** Screen shake, particle crashes, floating Bangla-flavoured barks ("OI MAMA!", "DEKHE CHALA!"), haptics, honk & crash SFX, headlight beam, street-lamp glow.

## Controls (one thumb, honest)

| Input | Action |
|-------|--------|
| Hold left / right side | Steer |
| Tap 📣 button | HONK (the weapon) |
| Swipe up | Viral Rush (when charged) |
| ⏸ / Android back | Pause ("cha break") |

Throttle is automatic — the hustle never stops.

## The hazards

| | Damage | Notes |
|---|---|---|
| 🚌 Bus | 38 | Immune to honking. Bounces you sideways. Respect the bus. |
| 🛺 CNG | 22 | Weaves. Slightly honk-resistant. |
| 🚲 Rickshaw | 15 | Honk shoves it a lane over. |
| 🐕 Dog | 8 | Crosses the road at the worst time. Honk = instant scatter. |
| 🕳️ Pothole | 12 | Can't be honked at. It's a hole. |
| 📋 Mamla | ৳150 fine | Honk it out of the air. |
| 🚔 Police | ৳300 + dignity | Outlast your wanted stars or outrun them. |

## Run it

```bash
git clone https://github.com/<you>/traffic-tyrants.git
cd traffic-tyrants
flutter pub get
flutter run        # on a connected Android/iOS device
```

Requires Flutter 3.x. No API keys, no backend, no nonsense.

## How it's built

~2,000 lines of Dart in a deliberately simple architecture:

```
lib/
├── main.dart                 # Bootstrap: portrait, immersive, load save
├── game/
│   ├── constants.dart        # Every tunable number in one place
│   ├── entities.dart         # Obstacles, sergeants, mamlas, police, FX
│   ├── save_data.dart        # Wallet, upgrade tiers, records (shared_preferences)
│   ├── game_engine.dart      # Simulation: scroll, spawns, fares, collisions, economy
│   ├── game_painter.dart     # Rendering: one CustomPainter draws the whole street
│   └── audio.dart            # Pooled SFX + haptics
└── screens/
    ├── menu_screen.dart      # Title, wallet, start/garage
    ├── garage_screen.dart    # The upgrade shop
    ├── game_screen.dart      # Touch input, honk button, pause
    └── game_over_screen.dart # Shift report
```

Design notes worth stealing:

- **Engine and renderer never touch.** `GameEngine` is a pure `ChangeNotifier` simulation on a delta-time `Ticker`; `GamePainter` just reads its state. Widgets rebuild only on transitions (phase, honk-ready, viral-ready), never 60×/s.
- **The world is procedural.** Roadside props (🌳🏪🕌, street lamps) are seeded from the scroll offset — infinite street, zero assets, perfectly stable as you ride.
- **TextPainter caching** with alpha quantization keeps emoji rendering cheap; the cache evicts in halves to avoid frame hitches.
- **Every gameplay number lives in `constants.dart`** — rebalancing the entire economy is a one-file edit.

## Contributing

PRs are very welcome — the codebase reads in one sitting. Ideas up for grabs:

- 🌧️ Rain shifts — wet handling, higher fares
- 🚚 New traffic — parked trucks, oncoming lane, ambulances you must yield to
- 🎯 Fare variety — parcel delivery, VIP (double pay, triple mood decay), school run
- 🏍️ Buyable bikes, not just upgrades
- 🎵 Background music + a real horn sample per horn tier
- 🌐 Bangla localization (the game begs for it)
- 🏆 Daily challenges / leaderboard
- ✅ Engine unit tests (`GameEngine` runs headless)

Workflow: fork → branch → `flutter analyze` clean → PR with a short clip if it's visual.

## The lore

*Mamla* (মামলা) = a court case. In Dhaka traffic mythology, an unlucky biker collects them like Pokémon. This game is affectionate satire — dodge the paperwork, out-hustle the tyrants, go viral.

**A game of many names.** This project has been reincarnated more times than a soap-opera villain: it began as a weekend pygame *Chicken Invaders* clone (`Main.py` + `src/`, kept in the repo unmodified for archaeology), became the *Mamla Invaders* formation shooter, flirted with *Chicken Henten* and *Mama Brake Kor!* — and the two ideas finally merged into **Traffic Tyrants**: the shooter's honk-and-mamla combat, riding shotgun on the ride-share hustle.

---

*"Roads break bikes. Bikes don't break riders."* 🏍️💨

*© BlankFrame Technologies*
