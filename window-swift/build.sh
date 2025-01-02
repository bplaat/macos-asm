#!/bin/sh
set -e
mkdir -p BassieTest.app/Contents/MacOS
if [[ $1 = "release" ]]; then
    swiftc -Osize -target arm64-macos src/main.swift -o BassieTest-arm64
    swiftc -Osize -target x86_64-macos src/main.swift -o BassieTest-x86_64
    strip BassieTest-arm64 BassieTest-x86_64
    lipo BassieTest-arm64 BassieTest-x86_64 -create -output BassieTest.app/Contents/MacOS/BassieTest
    rm BassieTest-arm64 BassieTest-x86_64
else
    swiftc src/main.swift -o BassieTest.app/Contents/MacOS/BassieTest
fi
cp Info.plist BassieTest.app/Contents
./BassieTest.app/Contents/MacOS/BassieTest
