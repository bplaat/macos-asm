#!/bin/sh
CFLAGS="-Wall -Wextra -Werror"
set -e
mkdir -p BassieTest.app
cp Info.plist BassieTest.app
clang $CFLAGS --target=arm64-apple-ios14-simulator src/main.c \
    -isysroot $(xcrun --sdk iphonesimulator --show-sdk-path) \
    -framework Foundation -framework UIKit -o BassieTest.app/BassieTest

xcrun simctl uninstall booted nl.plaatsoft.BassieTest
xcrun simctl install booted BassieTest.app
xcrun simctl launch --console booted nl.plaatsoft.BassieTest
