#!/bin/sh
name=BassieTest
CFLAGS="-x objective-c -fobjc-arc -Wall -Wextra -Werror"
set -e
mkdir -p $name.app/Contents/MacOS
clang $CFLAGS src/main.m -framework Cocoa -o $name.app/Contents/MacOS/$name
plutil -convert binary1 -o $name.app/Contents/Info.plist Info.plist
codesign --sign - --entitlements Entitlements.plist --options runtime $name.app
./$name.app/Contents/MacOS/$name
