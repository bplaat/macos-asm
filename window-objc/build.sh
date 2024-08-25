#!/bin/sh
set -e
mkdir -p BassieTest.app/Contents/MacOS
if [[ $1 = "release" ]]; then
    clang -x objective-c --target=arm64-macos -Os bassietest.m -framework Cocoa -o BassieTest-arm64
    clang -x objective-c --target=x86_64-macos -Os bassietest.m -framework Cocoa -o BassieTest-x86_64
    strip BassieTest-arm64 BassieTest-x86_64
    lipo BassieTest-arm64 BassieTest-x86_64 -create -output BassieTest.app/Contents/MacOS/BassieTest
    rm BassieTest-arm64 BassieTest-x86_64
else
    clang -x objective-c bassietest.m -framework Cocoa -o BassieTest.app/Contents/MacOS/BassieTest
fi
cp Info.plist BassieTest.app/Contents
open BassieTest.app
