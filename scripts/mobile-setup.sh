#!/usr/bin/env bash
# One-time Android SDK and Xcode setup. Safe to re-run.
#
# Nothing here belongs in a Home Manager activation: the SDK packages are
# multi-GB downloads under Google's license terms, and Xcode needs an Apple
# account. Run this manually after the first rebuild.
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ANDROID_API="${ANDROID_API:-37.0}"
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-37.0.0}"

if [ "$(uname -m)" = "arm64" ]; then
  DEFAULT_ABI="arm64-v8a"
else
  DEFAULT_ABI="x86_64"
fi
SYSTEM_IMAGE="${SYSTEM_IMAGE:-system-images/android-${ANDROID_API}/google_apis/${DEFAULT_ABI}}"

if ! command -v android >/dev/null 2>&1; then
  echo "android CLI not found. Run ./rebuild.sh first (installs android-cli)." >&2
  exit 1
fi

echo "==> Android SDK in $ANDROID_HOME"
mkdir -p "$ANDROID_HOME"
# android sdk is the replacement for the deprecated sdkmanager. It uses the
# Android CLI's license model, so there is no separate --licenses step.
android --sdk="$ANDROID_HOME" sdk install \
  "platform-tools" \
  "platforms/android-${ANDROID_API}" \
  "build-tools/${ANDROID_BUILD_TOOLS}" \
  "emulator" \
  "$SYSTEM_IMAGE"

echo "==> Xcode"
if [ -d /Applications/Xcode.app ]; then
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
else
  cat <<'EOF'
Xcode is not installed. Install it once, then re-run this script:

  xcodes signin
  xcodes install --latest --select

The App Store works too. Simulator runtimes are a separate download:

  xcodebuild -downloadPlatform iOS
EOF
fi

echo
echo "Done. Verify with: flutter doctor -v"
