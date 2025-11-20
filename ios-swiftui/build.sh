#!/bin/sh
name=BassieTest
set -e
mkdir -p $name.app
cp Info.plist $name.app
if [[ $1 = "device" ]]; then
    swiftc -Osize -target arm64-apple-ios14 \
        -sdk $(xcrun --sdk iphoneos --show-sdk-path) \
        -parse-as-library src/main.swift -o $name.app/$name
    strip $name.app/$name

    identity=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | awk '{print $2}')
    codesign --sign "$identity" $name.app --entitlements Entitlements.plist
    ios-deploy --bundle $name.app
else
    swiftc -target arm64-apple-ios14-simulator \
        -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) \
        -parse-as-library src/main.swift -o $name.app/$name

    xcrun simctl uninstall booted nl.plaatsoft.$name
    xcrun simctl install booted $name.app
    xcrun simctl launch --console booted nl.plaatsoft.$name
fi
