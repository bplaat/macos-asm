use std::env;
use std::fs::File;
use std::io::Write;

fn main() {
    // Generate Info.plist with cargo version
    let version = env::var("CARGO_PKG_VERSION").unwrap();
    let plist = format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleName</key>
	<string>BassieTest</string>
	<key>CFBundleDisplayName</key>
	<string>BassieTest</string>
	<key>CFBundleIdentifier</key>
	<string>nl.plaatsoft.BassieTest</string>
	<key>CFBundleVersion</key>
	<string>{}</string>
	<key>CFBundleShortVersionString</key>
	<string>{}</string>
	<key>CFBundleExecutable</key>
	<string>BassieTest</string>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2024-2025 Bastiaan van der Plaat</string>
</dict>
</plist>
"#,
        version, version
    );
    let mut plist_file = File::create("target/Info.plist").unwrap();
    plist_file.write_all(plist.as_bytes()).unwrap();
}
