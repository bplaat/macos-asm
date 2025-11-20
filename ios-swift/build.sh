#!/bin/sh
name=BassieTest
set -e
mkdir -p $name.app
cp Info.plist $name.app
swiftc -target arm64-apple-ios13-simulator \
    -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) \
    -parse-as-library src/main.swift -o $name.app/$name

xcrun simctl uninstall booted nl.plaatsoft.$name
xcrun simctl install booted $name.app
xcrun simctl launch --console booted nl.plaatsoft.$name
