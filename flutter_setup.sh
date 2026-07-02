#!/usr/bin/env bash
# Mamla Invaders – one-time Flutter project setup
# Run this ONCE from inside the Chicken-Invaders-Clone directory:
#   cd /path/to/Chicken-Invaders-Clone
#   bash flutter_setup.sh
set -e

PROJ="mamla_invaders"
ORG="com.the_abraar"

echo "==> Creating Flutter project scaffold..."
flutter create \
  --org "$ORG" \
  --project-name "$PROJ" \
  --platforms android,ios \
  .

echo "==> Restoring our source files over the generated ones..."
# pubspec.yaml and lib/ were already written — flutter create may overwrite them,
# so restore from git if that happens.
git checkout -- pubspec.yaml lib/ 2>/dev/null || true

echo "==> Getting packages..."
flutter pub get

echo ""
echo "✅ Done! Run the game:"
echo "   flutter run                          # on connected device"
echo "   flutter run -d <device-id>           # specific device"
echo "   flutter build apk --release          # Android APK"
echo "   flutter build ios --release          # iOS (needs Xcode)"
echo ""
echo "Game controls:"
echo "  Hold LEFT half  → move left"
echo "  Hold RIGHT half → move right"
echo "  Swipe UP        → Viral Blast (when orange bar is full)"
echo "  Auto-fires      → no tap needed"
