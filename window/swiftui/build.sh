#!/bin/sh
name=BassieTest
set -e
mkdir -p $name.app/Contents/MacOS
swiftc -parse-as-library src/main.swift -o $name.app/Contents/MacOS/$name
plutil -convert binary1 -o $name.app/Contents/Info.plist Info.plist
codesign --force --sign - --entitlements Entitlements.plist --options runtime $name.app
./$name.app/Contents/MacOS/$name
