#!/bin/sh
set -e
name=Alert
minimum_version=11.0

mkdir -p "$name.app/Contents/MacOS"
MACOSX_DEPLOYMENT_TARGET="$minimum_version" cargo build
cp target/debug/alert "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" target/Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
open "$name.app"
