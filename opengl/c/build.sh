#!/bin/sh
set -e

name=Triangle
mkdir -p "$name.app/Contents/MacOS"
clang -std=c23 -Wall -Wextra -Werror -Wno-cast-function-type-mismatch -Wno-deprecated-declarations \
    src/main.c -framework Cocoa -framework OpenGL \
    -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
