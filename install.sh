#!/bin/bash
set -e

REPO="shhivv/wideawake"
APP_NAME="WideAwake"
INSTALL_DIR="/Applications"

echo "Installing $APP_NAME..."

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -sL "https://github.com/$REPO/releases/latest/download/$APP_NAME.zip" -o "$tmpdir/$APP_NAME.zip"
unzip -q "$tmpdir/$APP_NAME.zip" -d "$tmpdir"

if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 0.5
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

mv "$tmpdir/$APP_NAME.app" "$INSTALL_DIR/"
xattr -cr "$INSTALL_DIR/$APP_NAME.app"

echo "$APP_NAME installed. Opening..."
open "$INSTALL_DIR/$APP_NAME.app"
