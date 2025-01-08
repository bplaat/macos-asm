#!/bin/sh
set -e
mkdir -p BassieTest.app/Contents/MacOS
if [[ $1 = "release" ]]; then
    for target in x86_64-apple-darwin aarch64-apple-darwin; do
        cargo +nightly build --release --target $target \
            -Z build-std=std,panic_abort \
            -Z build-std-features=optimize_for_size \
            -Z build-std-features=panic_immediate_abort
        strip target/$target/release/bassietest
    done
    lipo target/x86_64-apple-darwin/release/bassietest target/aarch64-apple-darwin/release/bassietest \
        -create -output BassieTest.app/Contents/MacOS/BassieTest
    cp target/Info.plist BassieTest.app/Contents
else
    cargo run --target x86_64-apple-darwin
fi
