#!/bin/sh
set -e
name=$(plutil -extract CFBundleExecutable raw Info.plist)
minimum_version=$(plutil -extract LSMinimumSystemVersion raw Info.plist)

mkdir -p target
mkdir -p "$name.app/Contents/MacOS"
xcrun --sdk macosx metal -mmacosx-version-min="$minimum_version" -c src/shaders.metal -o target/shaders.air
xcrun --sdk macosx metallib target/shaders.air -o target/default.metallib
clang -x objective-c -std=c23 --embed-dir=target --embed-dir=src/assets -fobjc-arc \
    -mmacosx-version-min="$minimum_version" -Wall -Wextra -Werror src/main.m -framework Cocoa \
    -framework ImageIO -framework Metal -framework MetalKit -framework QuartzCore \
    -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
