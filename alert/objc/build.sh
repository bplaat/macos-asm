#!/bin/sh
set -e

name=Alert
cflags="-x objective-c -fobjc-arc -Wall -Wextra -Werror"
mkdir -p "$name.app/Contents/MacOS"
clang $cflags src/main.m -framework Cocoa -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
open "$name.app"
