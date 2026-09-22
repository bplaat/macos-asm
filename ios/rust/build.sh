#!/bin/sh
set -e
name=BassieTest
bundle_id=nl.plaatsoft.BassieTest

mkdir -p "$name.app"
IPHONEOS_DEPLOYMENT_TARGET=15.0 cargo build --target aarch64-apple-ios-sim
cp target/aarch64-apple-ios-sim/debug/bassietest "$name.app/$name"
plutil -convert binary1 -o "$name.app/Info.plist" target/Info.plist

xcrun simctl uninstall booted "$bundle_id"
xcrun simctl install booted "$name.app"
xcrun simctl launch --console booted "$bundle_id"
