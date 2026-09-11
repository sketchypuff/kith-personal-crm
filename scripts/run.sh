#!/bin/bash
#
# Build Kith, install it on the simulator, and launch it.
#
#   scripts/run.sh              build, install, launch
#   scripts/run.sh --test       run the test suite instead
#   scripts/run.sh --fresh      wipe the app's data first, then seed samples
#   scripts/run.sh --shot       write a screenshot to /tmp/kith.png after launch
#
# The sample seed only fills an empty store, so --fresh is the way to get it
# back once anyone has been added.

set -euo pipefail

SCHEME="Kith"
PROJECT="Kith.xcodeproj"
DEVICE="${KITH_SIM_DEVICE:-iPhone 17 Pro}"
BUNDLE_ID="com.yashshenai.kith"
DESTINATION="platform=iOS Simulator,name=$DEVICE"

cd "$(dirname "$0")/.."

run_tests=false
fresh=false
shot=false
for arg in "$@"; do
  case "$arg" in
    --test) run_tests=true ;;
    --fresh) fresh=true ;;
    --shot) shot=true ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

if $run_tests; then
  echo "==> Testing on $DEVICE"
  # Surface failures and the summary only. The CloudKit teardown warnings the
  # in-memory containers emit on deinit are dropped first: they end in
  # "recover from an error:", which would otherwise match the failure filter.
  set +e
  xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" 2>&1 \
    | grep -v "CoreData+CloudKit" \
    | grep -E "✘|error:|failed|Test run|Executed"
  status=${PIPESTATUS[0]}
  set -e
  exit $status
fi

echo "==> Building $SCHEME for $DEVICE"
xcodebuild build -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" -quiet

# Ask xcodebuild where it put the app rather than hardcoding the DerivedData
# hash, which changes if the project is moved or re-cloned.
BUILD_DIR=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION" \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $2; exit}')
APP="$BUILD_DIR/$SCHEME.app"

[ -d "$APP" ] || { echo "no app at $APP" >&2; exit 1; }

# `simctl boot` fails if the device is already up, which is not an error here.
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator

# Wait for the device to finish booting: installing into a half-booted
# simulator fails intermittently.
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true

if $fresh; then
  echo "==> Wiping existing app data"
  xcrun simctl uninstall booted "$BUNDLE_ID" 2>/dev/null || true
fi

echo "==> Installing"
xcrun simctl install booted "$APP"

echo "==> Launching"
xcrun simctl launch booted "$BUNDLE_ID" -kith-seed-sample

if $shot; then
  sleep 4
  xcrun simctl io booted screenshot /tmp/kith.png >/dev/null 2>&1
  echo "==> Screenshot at /tmp/kith.png"
fi
