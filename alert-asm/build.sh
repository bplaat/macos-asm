#!/bin/sh
set -e
mkdir -p Alert.app/Contents/MacOS
nasm -f bin alert.s -o Alert.app/Contents/MacOS/Alert
chmod +x Alert.app/Contents/MacOS/Alert
plutil -convert binary1 -o Alert.app/Contents/Info.plist Info.plist
codesign --sign - --entitlements Entitlements.plist --options runtime Alert.app
open Alert.app
