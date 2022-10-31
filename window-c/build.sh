mkdir -p BassieTest.app/Contents/MacOS
if [[ $1 = "release" ]]; then
    gcc -Os bassietest.c -framework Cocoa -o BassieTest-arm64 || exit 1
    arch -x86_64 gcc -Os bassietest.c -framework Cocoa -o BassieTest-x86_64 || exit 1
    strip BassieTest-arm64 BassieTest-x86_64
    lipo BassieTest-arm64 BassieTest-x86_64 -create -output BassieTest.app/Contents/MacOS/BassieTest
    rm BassieTest-arm64 BassieTest-x86_64
else
    gcc bassietest.c -framework Cocoa -o BassieTest.app/Contents/MacOS/BassieTest || exit 1
fi
cp Info.plist BassieTest.app/Contents
open BassieTest.app
