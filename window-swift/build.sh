#!/bin/sh
name=BassieTest
set -e
mkdir -p $name.app/Contents/MacOS
if [[ $1 = "release" ]]; then
    swiftc -Osize -target arm64-macos src/main.swift -o $name-arm64
    swiftc -Osize -target x86_64-macos src/main.swift -o $name-x86_64
    strip $name-arm64 $name-x86_64
    lipo $name-arm64 $name-x86_64 -create -output $name.app/Contents/MacOS/$name
    rm $name-arm64 $name-x86_64
else
    swiftc src/main.swift -o $name.app/Contents/MacOS/$name
fi
cp Info.plist $name.app/Contents
./$name.app/Contents/MacOS/$name
