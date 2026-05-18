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
# For local dev, ad-hoc signing is used. For App Store, replace '-' with:
#   "3rd Party Mac Developer Application: <Your Name> (<TeamID>)"
# and ensure the entitlements file is referenced.
codesign --force --deep --sign - \
  --entitlements "Idol Follower.entitlements" \
  "$BUNDLE"

echo ""
echo "Done: $BUNDLE"
echo "Open: open \"$BUNDLE\""
