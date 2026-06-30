#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Appunti Archivio"
INSTALLER_APP="Installa Appunti Archivio.app"
VERSION="${1:-}"
VERSION="${VERSION#v}"
APP_PATH="${2:-$ROOT/build/Build/Products/Release/$APP_NAME.app}"

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
PKG_PATH="$OUT_DIR/Appunti-Archivio.pkg"

if [[ ! -f "$PKG_PATH" ]]; then
  chmod +x "$ROOT/Scripts/package-installer.sh"
  "$ROOT/Scripts/package-installer.sh" "$VERSION" "$APP_PATH" >/dev/null
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK" "$RW_DMG"' EXIT

INSTALLER_STAGING="$WORK/installer-app"
mkdir -p "$INSTALLER_STAGING/$INSTALLER_APP/Contents/MacOS"
mkdir -p "$INSTALLER_STAGING/$INSTALLER_APP/Contents/Resources"
cp "$PKG_PATH" "$INSTALLER_STAGING/$INSTALLER_APP/Contents/Resources/Appunti-Archivio.pkg"

cat >"$INSTALLER_STAGING/$INSTALLER_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>install</string>
  <key>CFBundleIdentifier</key>
  <string>com.clipboardarchivio.installer</string>
  <key>CFBundleName</key>
  <string>Installa Appunti Archivio</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
</dict>
</plist>
PLIST

cat >"$INSTALLER_STAGING/$INSTALLER_APP/Contents/MacOS/install" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$APP_ROOT/Resources/Appunti-Archivio.pkg"

if [[ ! -f "$PKG" ]]; then
  osascript -e 'display alert "Pacchetto di installazione non trovato." buttons {"OK"} default button 1'
  exit 1
fi

if /usr/sbin/installer -pkg "$PKG" -target /; then
  osascript -e 'display notification "Appunti Archivio è stato installato in Applicazioni." with title "Installazione completata"'
  VOLUME="$(df "$APP_ROOT" | awk 'END {print $NF}')"
  if [[ "$VOLUME" == /Volumes/* ]]; then
    hdiutil detach "$VOLUME" -quiet 2>/dev/null || true
  fi
else
  open "$PKG"
fi
SCRIPT
chmod +x "$INSTALLER_STAGING/$INSTALLER_APP/Contents/MacOS/install"

RW_DMG="$(mktemp -t appunti-rw).dmg"
DMG_PATH="$OUT_DIR/Appunti-Archivio.dmg"
VERSIONED_DMG="$OUT_DIR/Appunti-Archivio-v${VERSION}.dmg"
MOUNT_DIR="/Volumes/$APP_NAME"

hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
hdiutil create -size 48m -fs HFS+ -volname "$APP_NAME" "$RW_DMG" >/dev/null
hdiutil attach "$RW_DMG" -nobrowse -readwrite >/dev/null

ditto "$INSTALLER_STAGING/$INSTALLER_APP" "$MOUNT_DIR/$INSTALLER_APP"

bless --folder "$MOUNT_DIR" --openfolder "$MOUNT_DIR" 2>/dev/null || true

osascript <<EOF || true
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {140, 100, 640, 380}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 120
    set position of item "$INSTALLER_APP" of container window to {250, 120}
    close
  end tell
end tell
EOF

hdiutil detach "$MOUNT_DIR" >/dev/null
hdiutil convert "$RW_DMG" -format UDZO -o "$DMG_PATH" >/dev/null
cp "$DMG_PATH" "$VERSIONED_DMG"
rm -f "$RW_DMG"

echo "$DMG_PATH"