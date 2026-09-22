#!/bin/sh
set -e
name=BassieTest
bundle_id=nl.plaatsoft.BassieTest
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)

mkdir -p "$name.app"
plutil -convert binary1 -o "$name.app/Info.plist" Info.plist
clang -Wall -Wextra -Werror -Wno-cast-function-type-mismatch \
    --target=arm64-apple-ios15-simulator src/main.c \
    -isysroot "$sdk" \
    -framework Foundation -framework UIKit -o "$name.app/$name"

if xcrun simctl get_app_container booted "$bundle_id" app >/dev/null 2>&1; then
    xcrun simctl uninstall booted "$bundle_id"
fi
xcrun simctl install booted "$name.app"
xcrun simctl launch --console booted "$bundle_id"
