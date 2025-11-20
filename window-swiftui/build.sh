#!/bin/sh
name=BassieTest
set -e
mkdir -p $name.app/Contents/MacOS
swiftc -parse-as-library src/main.swift -o $name.app/Contents/MacOS/$name
cp Info.plist $name.app/Contents
./$name.app/Contents/MacOS/$name
