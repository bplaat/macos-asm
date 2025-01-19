#!/bin/sh
name=BassieTest
CFLAGS="-x objective-c -Wall -Wextra -Werror"
set -e
mkdir -p $name.app
cp Info.plist $name.app
clang $CFLAGS --target=arm64-apple-ios14-simulator src/main.m \
    -isysroot $(xcrun --sdk iphonesimulator --show-sdk-path) \
    -framework Foundation -framework UIKit -o $name.app/$name

xcrun simctl uninstall booted nl.plaatsoft.$name
xcrun simctl install booted $name.app
xcrun simctl launch --console booted nl.plaatsoft.$name
