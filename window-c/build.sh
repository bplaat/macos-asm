mkdir -p BassieTest.app/Contents/MacOS
gcc bassietest.c -framework Cocoa -o BassieTest.app/Contents/MacOS/BassieTest || exit 1
cp Info.plist BassieTest.app/Contents
open BassieTest.app
