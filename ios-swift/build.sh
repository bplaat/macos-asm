#!/bin/sh
set -e
mkdir -p BassieTest.app
cp Info.plist BassieTest.app
if [[ $1 = "device" ]]; then
    swiftc -Osize -target arm64-apple-ios14 \
        -sdk $(xcrun --sdk iphoneos --show-sdk-path) \
        -parse-as-library src/main.swift -o BassieTest.app/BassieTest

    identity=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | awk '{print $2}')
    codesign --sign "$identity" BassieTest.app --entitlements Entitlements.plist
    ios-deploy --bundle BassieTest.app
else
    swiftc -target x86_64-apple-ios14-simulator \
        -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) \
        -parse-as-library src/main.swift -o BassieTest.app/BassieTest

    xcrun simctl uninstall booted nl.plaatsoft.BassieTest
    xcrun simctl install booted BassieTest.app
    xcrun simctl launch booted nl.plaatsoft.BassieTest
fi
