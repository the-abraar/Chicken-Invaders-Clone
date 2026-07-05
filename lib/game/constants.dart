// Traffic Tyrants — every tunable number in one place.

// ── Road layout ───────────────────────────────────────────────────────────────
const double kShoulderFrac = 0.14; // sidewalk width, each side, as fraction of sw
const int    kLanes        = 3;
const double kPxPerMeter   = 12.0; // world scale: 12 px = 1 m

// ── Bike ──────────────────────────────────────────────────────────────────────
const double kBikeW = 30.0;  // collision box
const double kBikeH = 58.0;
const double kMaxHp = 100.0;

// Upgrade curves (tier 0–5)
const int    kTierMax        = 5;
const int    kUpCostBase     = 400;   // cost of tier n+1 = base * 2^n
const double kSpeedBase      = 260.0; // scroll px/s
const double kSpeedPerTier   = 40.0;
const double kSteerBase      = 250.0; // lateral px/s
const double kSteerPerTier   = 45.0;
const double kHonkRadiusBase = 130.0;
const double kHonkRadiusTier = 22.0;
const double kHonkCdBase     = 2.4;
const double kHonkCdTier     = 0.25;
const double kSeatTipPerTier = 0.08;  // +8% fare per seat tier
const double kSeatMoodPerTier= 0.12;  // −12% mood decay per seat tier
const double kGuardPerTier   = 0.10;  // −10% damage per guard tier

// ── Traffic ───────────────────────────────────────────────────────────────────
// Obstacle own speeds (they drive the same direction, slower than you)
const double kRickshawSpeed = 70.0;
const double kCngSpeed      = 130.0;
const double kBusSpeed      = 95.0;
const double kDogSpeed      = 0.0;   // dogs cross, they don't drive
const double kDogCrossVx    = 85.0;

// Damage on collision (before guard reduction)
const double kDmgBus      = 38.0;
const double kDmgCng      = 22.0;
const double kDmgRickshaw = 15.0;
const double kDmgDog      = 8.0;
const double kDmgPothole  = 12.0;

// ── Mamlas & sergeants ────────────────────────────────────────────────────────
const double kMamlaW       = 22.0;
const double kMamlaH       = 28.0;
const double kMamlaSpeed   = 220.0; // own flight speed toward player
const double kMamlaMaxAimVx = 130.0;
const double kMamlaFine    = 150.0; // ৳ fine when a mamla lands on you
const double kSergeantStagger = 3.0; // seconds a honk silences a sergeant

// ── Police / wanted ───────────────────────────────────────────────────────────
const int    kWantedMax       = 3;
const double kWantedDecayTime = 12.0; // seconds per star without incidents
const double kPoliceFine      = 300.0;

// ── Fares ─────────────────────────────────────────────────────────────────────
const double kFareMinM  = 220.0;  // dropoff distance range (metres)
const double kFareMaxM  = 480.0;
const double kFareBase  = 60.0;   // ৳
const double kFarePerM  = 0.9;    // ৳ per metre
const double kMoodDecay = 0.05;   // mood units per second while carrying
const double kTipPerShave = 3.0;  // ৳ per combo point at dropoff (capped ×20)

// ── Honk / viral ──────────────────────────────────────────────────────────────
const double kViralPerShave   = 0.06;
const double kViralPerDeliver = 0.18;
const double kViralPerMamla   = 0.05;
const double kViralRushTime   = 4.5;
const double kViralSpeedMult  = 1.6;

// ── Timing ────────────────────────────────────────────────────────────────────
const double kGetReadyDuration   = 2.2;
const double kInvincibleDuration = 1.3;
const double kMarkerSize         = 46.0; // fare marker touch radius-ish
