#!/bin/sh
set -e

name=Triangle
mkdir -p "$name.app/Contents/MacOS"
clang -x objective-c -std=c23 -fobjc-arc -Wall -Wextra -Werror -Wno-deprecated-declarations \
    src/main.m -framework Cocoa -framework OpenGL \
    -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
