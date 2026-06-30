#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Appunti Archivio"
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

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

OUT_DIR="$ROOT/dist"
mkdir -p "$OUT_DIR"

COMPONENT_PKG="$STAGING/component.pkg"
PKG_PATH="$OUT_DIR/Appunti-Archivio.pkg"
VERSIONED_PKG="$OUT_DIR/Appunti-Archivio-v${VERSION}.pkg"

pkgbuild \
  --component "$APP_PATH" \
  --install-location "/Applications" \
  --identifier "com.clipboardarchivio.app.pkg" \
  --version "$VERSION" \
  "$COMPONENT_PKG"

productbuild \
  --package "$COMPONENT_PKG" \
  "$PKG_PATH"

cp "$PKG_PATH" "$VERSIONED_PKG"

echo "$PKG_PATH"