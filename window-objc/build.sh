#!/bin/sh
CFLAGS="-x objective-c -Wall -Wextra -Werror"
set -e
mkdir -p BassieTest.app/Contents/MacOS
if [[ $1 = "release" ]]; then
    clang $CFLAGS -Os --target=arm64-macos src/main.m -framework Cocoa -o BassieTest-arm64
    clang $CFLAGS -Os --target=x86_64-macos src/main.m -framework Cocoa -o BassieTest-x86_64
    strip BassieTest-arm64 BassieTest-x86_64
    lipo BassieTest-arm64 BassieTest-x86_64 -create -output BassieTest.app/Contents/MacOS/BassieTest
    rm BassieTest-arm64 BassieTest-x86_64
else
    clang $CFLAGS src/main.m -framework Cocoa -o BassieTest.app/Contents/MacOS/BassieTest
fi
cp Info.plist BassieTest.app/Contents
./BassieTest.app/Contents/MacOS/BassieTest
