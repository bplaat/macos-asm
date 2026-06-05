#!/bin/sh
name=BassieTest
set -e
mkdir -p $name.app
cargo build --target aarch64-apple-ios-sim
cp target/aarch64-apple-ios-sim/debug/$name $name.app
plutil -convert binary1 -o $name.app/Info.plist target/Info.plist

xcrun simctl uninstall booted nl.plaatsoft.$name
xcrun simctl install booted $name.app
xcrun simctl launch --console booted nl.plaatsoft.$name
