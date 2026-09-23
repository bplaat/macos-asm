#!/bin/sh
set -e
name=$(plutil -extract CFBundleExecutable raw Info.plist)
minimum_version=$(plutil -extract LSMinimumSystemVersion raw Info.plist)

mkdir -p "$name.app/Contents/MacOS"
clang -x objective-c -std=c23 --embed-dir=src/assets -fobjc-arc \
    -mmacosx-version-min="$minimum_version" -Wall -Wextra -Werror -Wno-deprecated-declarations \
    src/main.m -framework Cocoa -framework ImageIO -framework OpenGL -framework QuartzCore \
    -o "$name.app/Contents/MacOS/$name"
plutil -convert binary1 -o "$name.app/Contents/Info.plist" Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime "$name.app"
"$name.app/Contents/MacOS/$name"
