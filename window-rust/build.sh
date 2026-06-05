#!/bin/sh
name=BassieTest
set -e
mkdir -p $name.app/Contents/MacOS
cargo build
cp target/debug/bassietest $name.app/Contents/MacOS/$name
plutil -convert binary1 -o $name.app/Contents/Info.plist target/Info.plist
codesign --sign - --entitlements Entitlements.plist --options runtime $name.app
./$name.app/Contents/MacOS/$name
