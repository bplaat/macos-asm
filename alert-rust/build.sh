#!/bin/sh
set -e
mkdir -p Alert.app/Contents/MacOS
if [[ $1 = "release" ]]; then
    for target in x86_64-apple-darwin aarch64-apple-darwin; do
        cargo +nightly build --release --target $target \
            -Z build-std=std,panic_abort \
            -Z build-std-features=optimize_for_size \
            -Z build-std-features=panic_immediate_abort
        strip target/$target/release/alert
    done
    lipo target/x86_64-apple-darwin/release/alert target/aarch64-apple-darwin/release/alert \
        -create -output Alert.app/Contents/MacOS/Alert
else
    cargo build
    cp target/debug/alert Alert.app/Contents/MacOS/Alert
fi
cp target/Info.plist Alert.app/Contents
open Alert.app
