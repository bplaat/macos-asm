#!/bin/sh
set -e
name=$(plutil -extract CFBundleExecutable raw Info.plist)
minimum_version=$(plutil -extract LSMinimumSystemVersion raw Info.plist)

mkdir -p "$name.app/Contents/MacOS"
nasm -f bin alert.s -o "$name.app/Contents/MacOS/$name"
chmod +x "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
open "$name.app"
