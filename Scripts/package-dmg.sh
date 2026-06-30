#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Clipboard Archive"
APP_BUNDLE="$APP_NAME.app"
INSTALL_APP_NAME="Install Clipboard Archive"
INSTALL_APP_BUNDLE="${INSTALL_APP_NAME}.app"
PKG_RESOURCE="Clipboard-Archive.pkg"
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
PKG_PATH="$OUT_DIR/$PKG_RESOURCE"

chmod +x "$ROOT/Scripts/package-installer.sh"
"$ROOT/Scripts/package-installer.sh" "$VERSION" "$APP_PATH" >/dev/null

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK" "$RW_DMG"' EXIT

INSTALLER_STAGING="$WORK/installer-app"
mkdir -p "$INSTALLER_STAGING/$INSTALL_APP_BUNDLE/Contents/MacOS"
mkdir -p "$INSTALLER_STAGING/$INSTALL_APP_BUNDLE/Contents/Resources"
cp "$PKG_PATH" "$INSTALLER_STAGING/$INSTALL_APP_BUNDLE/Contents/Resources/$PKG_RESOURCE"

cat >"$INSTALLER_STAGING/$INSTALL_APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>install</string>
  <key>CFBundleIdentifier</key>
  <string>com.clipboardarchivio.installer</string>
  <key>CFBundleName</key>
  <string>$INSTALL_APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
</dict>
</plist>
PLIST

cat >"$INSTALLER_STAGING/$INSTALL_APP_BUNDLE/Contents/MacOS/install" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="\$(cd "\$(dirname "\$0")/.." && pwd)"
PKG="\$APP_ROOT/Resources/$PKG_RESOURCE"
INSTALLED_APP="/Applications/$APP_BUNDLE"

if [[ ! -f "\$PKG" ]]; then
  osascript -e 'display alert "Installer package not found." buttons {"OK"} default button 1'
  exit 1
fi

if /usr/sbin/installer -pkg "\$PKG" -target /; then
  sleep 0.5
  open "\$INSTALLED_APP" || true
  osascript -e 'display notification "Clipboard Archive is in the menu bar — complete the quick setup." with title "Installation complete"'
  VOLUME="\$(df "\$APP_ROOT" | awk 'END {print \$NF}')"
  if [[ "\$VOLUME" == /Volumes/* ]]; then
    sleep 1
    hdiutil detach "\$VOLUME" -quiet 2>/dev/null || true
  fi
else
  open "\$PKG"
fi
SCRIPT
chmod +x "$INSTALLER_STAGING/$INSTALL_APP_BUNDLE/Contents/MacOS/install"

RW_DMG="$(mktemp -t clipboard-archive-rw).dmg"
DMG_PATH="$OUT_DIR/Clipboard-Archive.dmg"
VERSIONED_DMG="$OUT_DIR/Clipboard-Archive-v${VERSION}.dmg"
MOUNT_DIR="/Volumes/$APP_NAME"

hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
hdiutil create -size 48m -fs HFS+ -volname "$APP_NAME" "$RW_DMG" >/dev/null
hdiutil attach "$RW_DMG" -nobrowse -readwrite >/dev/null

ditto "$INSTALLER_STAGING/$INSTALL_APP_BUNDLE" "$MOUNT_DIR/$INSTALL_APP_BUNDLE"

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
    set position of item "$INSTALL_APP_BUNDLE" of container window to {250, 120}
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