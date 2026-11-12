#!/bin/bash
# Captures the iPhone 6.9" App Store screenshots from the Companion's DEBUG fixtures (LW_COMPANION_FIXTURE).
# Run from the repo root: AppStore/screenshots/tools/ios-capture.sh [en-US uk]
set -euo pipefail

LOCALES=("${@:-en-US}")
[ $# -eq 0 ] && LOCALES=(en-US uk)
OUT=AppStore/screenshots
WORK="${TMPDIR:-/tmp}/lockwatcher-ios-shots"
WAIT=14
# slug:fixture; Pro is on in every fixture.
SHOTS=("01-alerts:proTriggers" "02-alert-detail-top:detail.usbConnected" "03-alert-detail-bottom:detail.usbConnected.bottom" "04-photos:proPhotos" "05-photo-detail:photoDetail")

mkdir -p "$WORK"
xcodebuild -project Lock-Watcher.xcodeproj -scheme Lock-Watcher-Companion -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$WORK/dd" build -quiet
APP="$WORK/dd/Build/Products/Debug-iphonesimulator/Lock-Watcher-Companion.app"
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")

SIM=$(xcrun simctl create "LW Shots" com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max "$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; print([r["identifier"] for r in json.load(sys.stdin)["runtimes"] if r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS") and r["isAvailable"] and "iPhone" not in r["identifier"]][-1])')")
trap 'xcrun simctl shutdown "$SIM" 2>/dev/null || true; xcrun simctl delete "$SIM"' EXIT
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" -b >/dev/null
xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl install "$SIM" "$APP"

for loc in "${LOCALES[@]}"; do
    lang=${loc%%-*}
    dir="$OUT/$loc/APP_IPHONE_69"
    mkdir -p "$dir"
    for shot in "${SHOTS[@]}"; do
        slug=${shot%%:*}
        fixture=${shot#*:}
        xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
        SIMCTL_CHILD_LW_COMPANION_FIXTURE=$fixture xcrun simctl launch "$SIM" "$BUNDLE" -AppleLanguages "($lang)" -AppleLocale "$loc" >/dev/null
        sleep "$WAIT"
        xcrun simctl io "$SIM" screenshot --type=png "$dir/$slug.png" >/dev/null 2>&1
        # App Store Connect rejects alpha; a JPEG round trip drops the channel.
        sips -s format jpeg "$dir/$slug.png" --out "$dir/$slug.jpg" >/dev/null
        sips -s format png "$dir/$slug.jpg" --out "$dir/$slug.png" >/dev/null
        rm "$dir/$slug.jpg"
    done
    asc screenshots validate --path "$dir" --device-type APP_IPHONE_69 | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["path"], "ready", d["readyFiles"], "/", d["totalFiles"], "errors", d["errorCount"])'
done
