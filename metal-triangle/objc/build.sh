#!/bin/sh
set -e

name=Triangle
mkdir -p target
mkdir -p "$name.app/Contents/MacOS"
xcrun --sdk macosx metal -c src/Shaders.metal -o target/Shaders.air
xcrun --sdk macosx metallib target/Shaders.air -o target/default.metallib
clang -x objective-c -std=c23 --embed-dir=target -fobjc-arc -Wall -Wextra -Werror \
    src/main.m -framework Cocoa -framework Metal -framework MetalKit \
    -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
