#!/bin/sh
set -e
mkdir -p Alert.app/Contents/MacOS
nasm -f bin alert.s -o Alert.app/Contents/MacOS/Alert
chmod +x Alert.app/Contents/MacOS/Alert
cp Info.plist Alert.app/Contents
open Alert.app
