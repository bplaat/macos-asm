#!/bin/sh
set -e

name=Alert
cflags="-Wall -Wextra -Werror -Wno-cast-function-type-mismatch"
mkdir -p "$name.app/Contents/MacOS"
clang $cflags src/main.c -framework Cocoa -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
open "$name.app"
