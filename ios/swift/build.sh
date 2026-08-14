#!/bin/sh
set -e

name=BassieTest
bundle_id=nl.plaatsoft.BassieTest
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
mkdir -p "$name.app"
plutil -convert binary1 -o "$name.app/Info.plist" Info.plist
swiftc -target arm64-apple-ios15-simulator \
    -sdk "$sdk" \
    -parse-as-library src/main.swift -o "$name.app/$name"

xcrun simctl uninstall booted "$bundle_id"
xcrun simctl install booted "$name.app"
xcrun simctl launch --console booted "$bundle_id"
