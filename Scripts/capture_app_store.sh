#!/bin/bash
# Capture the shipping Release UI at native App Store dimensions.
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE_ID="${SARJBUL_SCREENSHOT_DEVICE:-}"
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for runtime, rows in json.load(sys.stdin)["devices"].items()
           if "iOS" in runtime for d in rows if d["name"] == "iPhone 17 Pro Max"]
if not devices:
    sys.exit("Install an iPhone 17 Pro Max simulator, or set SARJBUL_SCREENSHOT_DEVICE to a 1320 × 2868 device.")
print(devices[0]["udid"])
')"
fi
CAPTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp/}sarjbul-store.XXXXXX")"
DERIVED_DATA="$PWD/.build/app-store"
OUTPUT="$PWD/Docs/app-store"
PACKAGE_OPTIONS=()
if [[ -n "${SARJBUL_PACKAGE_CACHE:-}" ]]; then
  PACKAGE_OPTIONS=(-clonedSourcePackagesDirPath "$SARJBUL_PACKAGE_CACHE")
fi

xcodegen generate
COMMON=(-quiet -project SarjBul.xcodeproj -scheme SarjBulStoreScreenshots
  -configuration Release -destination "platform=iOS Simulator,id=$DEVICE_ID"
  -derivedDataPath "$DERIVED_DATA" -parallel-testing-enabled NO
  -only-testing:SarjBulUITests/AppStoreScreenshotTests CODE_SIGNING_ALLOWED=NO)
xcodebuild "${COMMON[@]}" "${PACKAGE_OPTIONS[@]}" build-for-testing

if ! xcrun simctl list devices booted -j | python3 -c '
import json, sys
device_id = sys.argv[1]
sys.exit(0 if any(d["udid"] == device_id for rows in json.load(sys.stdin)["devices"].values() for d in rows) else 1)
' "$DEVICE_ID"; then
  xcrun simctl boot "$DEVICE_ID"
fi
xcrun simctl bootstatus "$DEVICE_ID" -b
APP="$DERIVED_DATA/Build/Products/Release-iphonesimulator/SarjBul.app"
xcrun simctl install "$DEVICE_ID" "$APP"
xcrun simctl privacy "$DEVICE_ID" grant location com.ozdemirbaris.sarjbul
xcrun simctl location "$DEVICE_ID" set 38.4237,27.1428
xcrun simctl ui "$DEVICE_ID" appearance dark
xcrun simctl status_bar "$DEVICE_ID" override --time '9:41' --dataNetwork wifi \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100
trap 'xcrun simctl status_bar "$DEVICE_ID" clear || true' EXIT
xcodebuild "${COMMON[@]}" "${PACKAGE_OPTIONS[@]}" \
  -resultBundlePath "$CAPTURE_DIR/Capture.xcresult" test-without-building
xcrun xcresulttool export attachments --path "$CAPTURE_DIR/Capture.xcresult" \
  --output-path "$CAPTURE_DIR/attachments"
python3 Scripts/export_app_store.py "$CAPTURE_DIR/attachments" "$OUTPUT" --built-app "$APP"
echo "App Store assets: $OUTPUT"
echo "Original XCTest evidence: $CAPTURE_DIR/Capture.xcresult"
