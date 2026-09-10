#!/bin/sh
set -e
name=Triangle
minimum_version=11.0

mkdir -p target
mkdir -p "$name.app/Contents/MacOS"
xcrun --sdk macosx metal -mmacosx-version-min="$minimum_version" -c src/Shaders.metal -o target/Shaders.air
xcrun --sdk macosx metallib target/Shaders.air -o target/default.metallib
MACOSX_DEPLOYMENT_TARGET="$minimum_version" cargo build
cp target/debug/triangle "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" target/Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
