#!/bin/bash
set -e

BUNDLE="Idol Follower.app"
BINARY="IdolFollower"

echo "Building $BINARY..."
swift build -c release

echo "Packaging $BUNDLE..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

cp ".build/release/$BINARY"    "$BUNDLE/Contents/MacOS/$BINARY"
cp "Resources/Info.plist"      "$BUNDLE/Contents/Info.plist"

echo "Generating icon..."
swift Scripts/make_icon.swift
iconutil -c icns /tmp/IdolFollower.iconset -o "$BUNDLE/Contents/Resources/AppIcon.icns"

echo "Signing..."
# Ad-hoc signing for local dev — no sandbox enforced, path-based persistence works.
# For App Store: replace '-' with "3rd Party Mac Developer Application: <Name> (<TeamID>)"
# and add: --entitlements "Idol Follower.entitlements"
codesign --force --deep --sign - "$BUNDLE"

echo ""
echo "Done: $BUNDLE"
echo "Open: open \"$BUNDLE\""
