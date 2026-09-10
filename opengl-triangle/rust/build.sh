#!/bin/sh
set -e

name=Triangle
mkdir -p "$name.app/Contents/MacOS"
cargo build
cp target/debug/triangle "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" target/Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
