#!/bin/sh
set -e
name=$(plutil -extract CFBundleExecutable raw Info.plist)
minimum_version=$(plutil -extract LSMinimumSystemVersion raw Info.plist)

mkdir -p target
mkdir -p "$name.app/Contents/MacOS" "$name.app/Contents/Resources"
xcrun --sdk macosx metal -mmacosx-version-min="$minimum_version" -c src/Shaders.metal -o target/Shaders.air
xcrun --sdk macosx metallib target/Shaders.air -o "$name.app/Contents/Resources/default.metallib"
swiftc -target "$(uname -m)-apple-macosx$minimum_version" -import-objc-header src/ShaderTypes.h \
    src/main.swift -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
