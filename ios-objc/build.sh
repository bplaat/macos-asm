#!/bin/sh
set -e

name=BassieTest
bundle_id=nl.plaatsoft.BassieTest

# Build for real device if provision.sh exists and device is connected, else simulator
if [ -f provision.sh ]; then
    . ./provision.sh
fi

if [ -n "$device_id" ] && xcrun devicectl list devices 2>/dev/null | grep -q "$device_id"; then
    sdk=$(xcrun --sdk iphoneos --show-sdk-path)
    mkdir -p $name.app
    cp Info.plist $name.app
    clang -x objective-c -Wall -Wextra -Werror \
        --target=arm64-apple-ios15 \
        -isysroot "$sdk" \
        -framework Foundation -framework UIKit \
        src/main.m -o $name.app/$name

    cp "$provision" $name.app/embedded.mobileprovision

    cat > /tmp/$name.entitlements.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>$team_id.$bundle_id</string>
    <key>com.apple.developer.team-identifier</key>
    <string>$team_id</string>
    <key>get-task-allow</key>
    <true/>
</dict>
</plist>
EOF

    codesign --force --sign "$sign_id" \
        --entitlements /tmp/$name.entitlements.plist \
        --timestamp=none \
        $name.app

    xcrun devicectl device install app --device "$device_id" $name.app
    xcrun devicectl device process launch --device "$device_id" $bundle_id
else
    sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
    mkdir -p $name.app
    cp Info.plist $name.app
    clang -x objective-c -Wall -Wextra -Werror \
        --target=arm64-apple-ios15-simulator \
        -isysroot "$sdk" \
        -framework Foundation -framework UIKit \
        src/main.m -o $name.app/$name

    xcrun simctl uninstall booted $bundle_id
    xcrun simctl install booted $name.app
    xcrun simctl launch --console booted $bundle_id
fi
