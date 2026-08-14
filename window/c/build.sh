#!/bin/sh
set -e

name=BassieTest
mkdir -p "$name.app/Contents/MacOS"
clang -Wall -Wextra -Werror -Wno-cast-function-type-mismatch \
    src/main.c -framework Cocoa -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
