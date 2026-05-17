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

echo "Bundling frameworks..."
mkdir -p "$BUNDLE/Contents/Frameworks"
GLTF_FW=$(find .build -name "GLTFKit2.framework" -path "*/release/GLTFKit2.framework" | head -1)
if [ -n "$GLTF_FW" ]; then
    cp -R "$GLTF_FW" "$BUNDLE/Contents/Frameworks/"
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$BUNDLE/Contents/MacOS/$BINARY" 2>/dev/null || true
else
    echo "Warning: GLTFKit2.framework not found in .build/release"
fi

echo "Generating icon..."
swift Scripts/make_icon.swift
iconutil -c icns /tmp/IdolFollower.iconset -o "$BUNDLE/Contents/Resources/AppIcon.icns"

echo "Signing..."
codesign --force --deep --sign - "$BUNDLE"

echo ""
echo "Done: $BUNDLE"
echo "Open: open \"$BUNDLE\""
