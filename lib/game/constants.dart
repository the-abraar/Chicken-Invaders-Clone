// ── Grid ─────────────────────────────────────────────────────────────────────
const int kRows = 4;
const int kCols = 9;
const int kTotalEnemies = kRows * kCols; // 36

// ── Entity sizes (logical px) ─────────────────────────────────────────────────
const double kEnemyW = 36.0;
const double kEnemyH = 36.0;
const double kEnemySpacingX = 52.0;
const double kEnemySpacingY = 52.0;
const double kEnemyStartY = 95.0;

const double kPlayerW = 54.0;
const double kPlayerH = 44.0;

const double kBulletW = 5.0;
const double kBulletH = 18.0;

const double kMamlaW = 22.0;
const double kMamlaH = 28.0;

const double kPowerUpSize = 30.0;

const double kBossW = 88.0;
const double kBossH = 64.0;

// ── Speeds ────────────────────────────────────────────────────────────────────
const double kPlayerSpeed    = 230.0;
const double kBulletSpeed    = 500.0;
const double kMamlaBaseSpeed = 120.0;
const double kEnemyBaseSpeed =  50.0;
const double kPowerUpFallSpeed = 75.0;

// ── Timing ────────────────────────────────────────────────────────────────────
const double kShootCooldown       = 0.33;
const double kInvincibleDuration  = 2.2;
const double kFormationDrop       = 26.0;

// ── Scoring ───────────────────────────────────────────────────────────────────
const double kViralPerKill = 0.09; // ~11 kills to charge
