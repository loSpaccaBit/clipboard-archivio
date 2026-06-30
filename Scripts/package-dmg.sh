#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Clipboard Archive"
APP_BUNDLE="$APP_NAME.app"
INSTALL_APP_NAME="Install Clipboard Archive"
INSTALL_APP_BUNDLE="${INSTALL_APP_NAME}.app"
VERSION="${1:-}"
VERSION="${VERSION#v}"
APP_PATH="${2:-$ROOT/build/Build/Products/Release/$APP_BUNDLE}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found at $APP_PATH" >&2
  echo "run: make build" >&2
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
fi

OUT_DIR="$ROOT/dist"
mkdir -p "$OUT_DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK" "$RW_DMG"' EXIT

STAGING="$WORK/dmg-root"
mkdir -p "$STAGING"
ditto "$APP_PATH" "$STAGING/$APP_BUNDLE"
ln -s /Applications "$STAGING/Applications"

cat >"$WORK/install.applescript" <<'APPLESCRIPT'
on run
	try
		set installPOSIX to POSIX path of (path to me)
		if installPOSIX ends with "/" then
			set installPOSIX to text 1 thru -2 of installPOSIX
		end if
		set dmgRoot to do shell script "dirname " & quoted form of installPOSIX
		set sourceApp to dmgRoot & "/Clipboard Archive.app"
		set destApp to "/Applications/Clipboard Archive.app"

		do shell script "test -d " & quoted form of sourceApp
		do shell script "ditto " & quoted form of sourceApp & " " & quoted form of destApp with administrator privileges

		delay 0.3
		do shell script "open " & quoted form of destApp

		delay 1
		do shell script "hdiutil detach " & quoted form of dmgRoot & " -quiet 2>/dev/null || true"

		display notification "Clipboard Archive is in the menu bar — complete the quick setup." with title "Installation complete"
	on error errMsg
		display alert "Installation failed" message (errMsg as text) buttons {"OK"} default button "OK" as critical
	end try
end run
APPLESCRIPT

osacompile -o "$STAGING/$INSTALL_APP_BUNDLE" "$WORK/install.applescript"

RW_DMG="$(mktemp -t clipboard-archive-rw).dmg"
DMG_PATH="$OUT_DIR/Clipboard-Archive.dmg"
VERSIONED_DMG="$OUT_DIR/Clipboard-Archive-v${VERSION}.dmg"
MOUNT_DIR="/Volumes/$APP_NAME"

hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
hdiutil create -size 64m -fs HFS+ -volname "$APP_NAME" "$RW_DMG" >/dev/null
hdiutil attach "$RW_DMG" -nobrowse -readwrite >/dev/null

ditto "$STAGING/$APP_BUNDLE" "$MOUNT_DIR/$APP_BUNDLE"
ditto "$STAGING/$INSTALL_APP_BUNDLE" "$MOUNT_DIR/$INSTALL_APP_BUNDLE"
ln -s /Applications "$MOUNT_DIR/Applications"

bless --folder "$MOUNT_DIR" --openfolder "$MOUNT_DIR" 2>/dev/null || true

osascript <<EOF || true
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {160, 100, 920, 420}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set position of item "$INSTALL_APP_BUNDLE" of container window to {120, 185}
    set position of item "$APP_BUNDLE" of container window to {400, 185}
    set position of item "Applications" of container window to {680, 185}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

hdiutil detach "$MOUNT_DIR" >/dev/null
rm -f "$DMG_PATH"
hdiutil convert "$RW_DMG" -format UDZO -o "$DMG_PATH" >/dev/null
cp "$DMG_PATH" "$VERSIONED_DMG"

echo "$DMG_PATH"