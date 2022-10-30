mkdir -p BassieTest.app/Contents/MacOS
gcc bassietest.c -framework Cocoa -o BassieTest-arm64 || exit 1
arch -x86_64 gcc bassietest.c -framework Cocoa -o BassieTest-x86_64 || exit 1
lipo BassieTest-arm64 BassieTest-x86_64 -create -output BassieTest.app/Contents/MacOS/BassieTest
rm BassieTest-arm64 BassieTest-x86_64
cp Info.plist BassieTest.app/Contents
open BassieTest.app
