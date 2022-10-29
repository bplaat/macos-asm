mkdir -p BassieTest.app/Contents/MacOS
gcc -x objective-c bassietest.m -framework Cocoa -o BassieTest.app/Contents/MacOS/BassieTest
cp Info.plist BassieTest.app/Contents
open BassieTest.app
