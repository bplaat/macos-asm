use std::env;
use std::fs;

fn main() {
    let version = env::var("CARGO_PKG_VERSION").expect("CARGO_PKG_VERSION should be set by Cargo");
    let plist = format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleName</key>
	<string>Triangle</string>
	<key>CFBundleDisplayName</key>
	<string>Triangle</string>
	<key>CFBundleIdentifier</key>
	<string>nl.plaatsoft.Triangle</string>
	<key>CFBundleVersion</key>
	<string>{version}</string>
	<key>CFBundleShortVersionString</key>
	<string>{version}</string>
	<key>CFBundleExecutable</key>
	<string>Triangle</string>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright (c) 2026 Bastiaan van der Plaat</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
"#
    );

    fs::create_dir_all("target").expect("failed to create target directory");
    fs::write("target/Info.plist", plist).expect("failed to write target/Info.plist");
}
