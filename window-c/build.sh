#!/bin/sh
name=BassieTest
CFLAGS="-Wall -Wextra"
set -e
mkdir -p $name.app/Contents/MacOS
if [[ $1 = "release" ]]; then
    clang $CFLAGS -Os --target=arm64-macos src/main.c -framework Cocoa -o $name-arm64
    clang $CFLAGS -Os --target=x86_64-macos src/main.c -framework Cocoa -o $name-x86_64
    strip $name-arm64 $name-x86_64
    lipo $name-arm64 $name-x86_64 -create -output $name.app/Contents/MacOS/$name
    rm $name-arm64 $name-x86_64
else
    clang $CFLAGS src/main.c -framework Cocoa -o $name.app/Contents/MacOS/$name
fi
cp Info.plist $name.app/Contents
./$name.app/Contents/MacOS/$name
