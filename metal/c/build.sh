#!/bin/sh
set -e

name=Triangle
mkdir -p target
mkdir -p "$name.app/Contents/MacOS" "$name.app/Contents/Resources"
xcrun --sdk macosx metal -c src/Shaders.metal -o target/Shaders.air
xcrun --sdk macosx metal target/Shaders.air -o "$name.app/Contents/Resources/default.metallib"
clang -Wall -Wextra -Werror -Wno-cast-function-type-mismatch \
    src/main.c -framework Cocoa -framework Metal -framework MetalKit \
    -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
