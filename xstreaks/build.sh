#!/bin/sh

name=XStreaks
CFLAGS="-x objective-c -Wall -Wextra -Werror"

set -e

genstrings src/main.m -o Resources/en.lproj
iconv -f UTF-16 -t UTF-8 Resources/en.lproj/Localizable.strings > /tmp/Localizable.strings
mv /tmp/Localizable.strings Resources/en.lproj/Localizable.strings

mkdir -p $name.app/Contents/MacOS
if [[ $1 = "release" ]]; then
    clang $CFLAGS -Os --target=arm64-macos src/main.m -framework Cocoa -o $name-arm64
    clang $CFLAGS -Os --target=x86_64-macos src/main.m -framework Cocoa -o $name-x86_64
    strip $name-arm64 $name-x86_64
    lipo $name-arm64 $name-x86_64 -create -output $name.app/Contents/MacOS/$name
    rm $name-arm64 $name-x86_64
else
    clang $CFLAGS src/main.m -framework Cocoa -o $name.app/Contents/MacOS/$name
fi

cp -r Resources Info.plist $name.app/Contents
iconutil -c icns icons/app_icon.iconset -o $name.app/Contents/Resources/app_icon.icns

./$name.app/Contents/MacOS/$name
