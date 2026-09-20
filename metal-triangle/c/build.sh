#!/bin/sh
set -e
name=$(plutil -extract CFBundleExecutable raw Info.plist)
minimum_version=$(plutil -extract LSMinimumSystemVersion raw Info.plist)

mkdir -p target
mkdir -p "$name.app/Contents/MacOS"
xcrun --sdk macosx metal -mmacosx-version-min="$minimum_version" -c src/shaders.metal -o target/shaders.air
xcrun --sdk macosx metallib target/shaders.air -o target/default.metallib
clang -std=c23 --embed-dir=target -mmacosx-version-min="$minimum_version" \
    -Wall -Wextra -Werror -Wno-cast-function-type-mismatch \
    src/main.c -framework CoreFoundation -framework Cocoa -framework Metal -framework MetalKit \
    -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
