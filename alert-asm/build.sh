mkdir -p Alert.app/Contents/MacOS
nasm -f bin alert.s -o Alert.app/Contents/MacOS/Alert || exit 1
chmod +x Alert.app/Contents/MacOS/Alert
codesign -s - Alert.app/Contents/MacOS/Alert
rm -rf Alert.app/Contents/_CodeSignature
cp Info.plist Alert.app/Contents
open Alert.app
