#!/bin/sh
set -e

name=BassieTest
bundle_id=nl.plaatsoft.BassieTest

# Build for real device if provision.sh exists and device is connected, else simulator
if [ -f provision.sh ]; then
    . ./provision.sh
fi

deploy_device_app() {
    case "$deploy_tool" in
        devicectl)
            xcrun devicectl device install app --device "$device_id" "$name.app"
            xcrun devicectl device process launch --device "$device_id" "$bundle_id"
            ;;
        ios-deploy)
            if ! command -v ios-deploy >/dev/null 2>&1; then
                echo "ios-deploy was not found" >&2
                exit 1
            fi
            ios-deploy --id "$device_id" --bundle "$name.app" --justlaunch --no-wifi --timeout 10
            ;;
        *)
            echo "Unknown deploy_tool: $deploy_tool" >&2
            exit 1
            ;;
    esac
}

if [ -n "$device_id" ] && { [ "$deploy_tool" = ios-deploy ] || xcrun devicectl list devices 2>/dev/null | grep -q "$device_id"; }; then
    sdk=$(xcrun --sdk iphoneos --show-sdk-path)
    mkdir -p $name.app
    plutil -convert binary1 -o $name.app/Info.plist Info.plist
    clang -x objective-c -fobjc-arc -Wall -Wextra -Werror \
        --target=arm64-apple-ios15 \
        -isysroot "$sdk" \
        -framework Foundation -framework UIKit \
        src/main.m -o $name.app/$name

    cp "$provision" $name.app/embedded.mobileprovision

    cat > /tmp/$name.Entitlements.plist <<EOF
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
        --entitlements /tmp/$name.Entitlements.plist \
        --timestamp=none \
        $name.app

    deploy_device_app
else
    sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
    mkdir -p $name.app
    plutil -convert binary1 -o $name.app/Info.plist Info.plist
    clang -x objective-c -fobjc-arc -Wall -Wextra -Werror \
        --target=arm64-apple-ios15-simulator \
        -isysroot "$sdk" \
        -framework Foundation -framework UIKit \
        src/main.m -o $name.app/$name

    xcrun simctl uninstall booted $bundle_id
    xcrun simctl install booted $name.app
    xcrun simctl launch --console booted $bundle_id
fi
