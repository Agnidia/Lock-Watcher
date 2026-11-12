#!/bin/bash
# Captures the raw windows for every slide in en-US and uk into AppStore/screenshots/<locale>/raw/.
# Needs build.sh first, the Mac unlocked with the display on, and Accessibility + Screen Recording access for the
# terminal: macOS cannot capture a window behind the lock screen.
set -euo pipefail
TOOLS=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$TOOLS/../../.." && pwd)
SHOTS="$REPO/AppStore/screenshots"
WORK=${WORK:-${TMPDIR:-/tmp}/lockwatcher-shots}
APP="$WORK/dd/Build/Products/Debug/Lock-Watcher.app"
BUNDLE=com.igrsoft.lockwatcher.shots
CONTAINER="$HOME/Library/Containers/$BUNDLE/Data/Library"

[ -d "$APP" ] && [ -x "$WORK/wins" ] || { echo "run build.sh first" >&2; exit 1; }
if ioreg -n Root -d1 -a | grep -q CGSSessionScreenIsLocked; then
  echo "the screen is locked; unlock the Mac and keep the display on" >&2; exit 1
fi
# The app reads its settings from the defaults suite named in the generated, gitignored Secrets.swift.
SUITE=$(sed -n 's/.*userDefaultsId *= *"\([^"]*\)".*/\1/p' "$REPO/Source/Application/Secrets.swift")
[ -n "$SUITE" ] || { echo "no userDefaultsId in Source/Application/Secrets.swift" >&2; exit 1; }

# launch <lang> <page>: seeds demo-safe settings and person history, then starts the app in <lang> with the
# Settings window set to <page> (a SettingsPage raw value stored in UISettings.lastSettingsPage).
launch() {
  pkill -f "$APP/Contents/MacOS" || true
  sleep 2
  python3 "$TOOLS/seed.py" "$WORK/history.json"
  mkdir -p "$CONTAINER/Application Support/Thiefs"
  cp "$WORK/history.json" "$CONTAINER/Application Support/Thiefs/images"
  python3 "$TOOLS/prefs.py" "$WORK/prefs.plist" "$2"
  defaults import "$CONTAINER/Preferences/$SUITE" "$WORK/prefs.plist"
  defaults write "$CONTAINER/Preferences/$BUNDLE" AppleKeyboardUIMode -int 0
  defaults write "$CONTAINER/Preferences/$BUNDLE" NSUseKeyboardFocusRing -bool NO
  open -n "$APP" --args -AppleLanguages "($1)" -AppleLocale "$1" -AppleKeyboardUIMode 0
  sleep 5
}

# window <layer>: the id and bounds of the app's first on-screen window in <layer> (25 = popover, 0 = Settings).
window() {
  "$WORK/wins" "$(pgrep -f "$APP/Contents/MacOS" | head -1)" | awk -v l="$1" '$2==l' | head -1
}

# capture <lang> <page> <settings-name> [popover-name]
capture() {
  local lang=$1 page=$2 out=$3 pop=${4:-}
  launch "$lang" "$page"
  osascript -e 'tell application "System Events" to tell process "Lock-Watcher" to click menu bar item 1 of menu bar 2' >/dev/null
  sleep 2
  read -r wid _ bx by _ <<< "$(window 25)"
  [ -n "$pop" ] && screencapture -l "$wid" -o -x "$pop"
  # The Settings button sits at a fixed offset inside the popover; recheck it if the popover layout changes.
  osascript -e "tell application \"System Events\" to click at {$((bx + 183)), $((by + 512))}" >/dev/null
  sleep 3
  read -r sid _ <<< "$(window 0)"
  # Clearing the first responder removes the focus ring the window draws around its first control.
  lldb -b -p "$(pgrep -f "$APP/Contents/MacOS" | head -1)" \
    -o 'expr -l objc -- (void)[(NSWindow *)[(NSApplication *)[NSApplication sharedApplication] keyWindow] makeFirstResponder:nil]' \
    -o 'process detach' >/dev/null 2>&1
  osascript -e "tell application id \"$BUNDLE\" to activate" >/dev/null
  sleep 1.5
  screencapture -l "$sid" -o -x "$out"
  echo "saved ${out#"$SHOTS/"}${pop:+ and ${pop#"$SHOTS/"}}"
}

for pair in en-US:en uk:uk; do
  locale=${pair%%:*}; lang=${pair##*:}; raw="$SHOTS/$locale/raw"
  mkdir -p "$raw"
  capture "$lang" capture "$raw/settings-capture.png" "$raw/menu-popover.png"
  capture "$lang" snapshot "$raw/settings-triggers.png"
  capture "$lang" sync "$raw/settings-sync.png"
  capture "$lang" notifications "$raw/settings-notifications.png"
done
pkill -f "$APP/Contents/MacOS" || true
echo "check every raw capture for a blue focus ring before composing"
