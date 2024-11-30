#!/bin/sh
set -e
mkdir -p BassieTest.app
cargo build --target aarch64-apple-ios-sim
cp target/Info.plist target/aarch64-apple-ios-sim/debug/BassieTest BassieTest.app

xcrun simctl uninstall booted nl.plaatsoft.BassieTest
xcrun simctl install booted BassieTest.app
xcrun simctl launch --console booted nl.plaatsoft.BassieTest
