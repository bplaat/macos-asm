#!/bin/sh
name=BassieTest
CFLAGS="-Wall -Wextra -Wno-cast-function-type-mismatch"
set -e
mkdir -p $name.app
plutil -convert binary1 -o $name.app/Info.plist Info.plist
clang $CFLAGS --target=arm64-apple-ios15-simulator src/main.c \
    -isysroot $(xcrun --sdk iphonesimulator --show-sdk-path) \
    -framework Foundation -framework UIKit -o $name.app/$name

xcrun simctl uninstall booted nl.plaatsoft.$name
xcrun simctl install booted $name.app
xcrun simctl launch --console booted nl.plaatsoft.$name
