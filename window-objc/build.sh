#!/bin/sh
name=BassieTest
CFLAGS="-x objective-c -Wall -Wextra -Werror"
set -e
mkdir -p $name.app/Contents/MacOS
clang $CFLAGS src/main.m -framework Cocoa -o $name.app/Contents/MacOS/$name
cp Info.plist $name.app/Contents
./$name.app/Contents/MacOS/$name
