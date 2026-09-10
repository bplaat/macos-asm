#!/bin/sh
set -e

name=Triangle
mkdir -p "$name.app/Contents/MacOS" "$name.app/Contents/Resources"
cp src/Shaders.vert src/Shaders.frag "$name.app/Contents/Resources"
swiftc -Xcc -DGL_SILENCE_DEPRECATION src/main.swift -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
