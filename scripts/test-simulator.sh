#!/bin/sh
set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: sh scripts/test-simulator.sh BOOTED_SIMULATOR_UDID [xcodebuild test options]" >&2
  exit 2
fi
simulator_id=$1
shift
cd "$(dirname "$0")/.."
destination="platform=iOS Simulator,id=$simulator_id"
app_path="build/Build/Products/Debug-iphonesimulator/FlipCardAlbum.app"

xcodebuild -project FlipCardAlbum.xcodeproj -scheme FlipCardAlbum \
  -derivedDataPath build -destination "$destination" \
  -parallel-testing-enabled NO build-for-testing

# A successful UI-test build alone did not replace the installed widget extension.
xcrun simctl install "$simulator_id" "$app_path"
installed_path=$(xcrun simctl get_app_container "$simulator_id" com.lpkiki.FlipCardAlbum app)
python3 scripts/verify-installed.py "$app_path" "$installed_path" \
  --report build/installed-before-tests.json

# Keep the test failure while still checking whether the installed bundle changed.
test_status=0
xcodebuild -project FlipCardAlbum.xcodeproj -scheme FlipCardAlbum \
  -derivedDataPath build -destination "$destination" \
  -parallel-testing-enabled NO test-without-building "$@" || test_status=$?

verification_status=0
if installed_path=$(xcrun simctl get_app_container "$simulator_id" com.lpkiki.FlipCardAlbum app); then
  python3 scripts/verify-installed.py "$app_path" "$installed_path" \
    --report build/installed-after-tests.json || verification_status=$?
else
  verification_status=$?
  echo "Unable to locate the installed app after testing." >&2
fi

if [ "$verification_status" -ne 0 ]; then
  echo "Post-test installation verification failed (exit $verification_status)." >&2
fi
if [ "$test_status" -ne 0 ]; then
  exit "$test_status"
fi
exit "$verification_status"
