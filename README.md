# macOS Assembly Examples

A collection of small macOS programs exploring Mach-O binaries, macOS Cocoa,
iOS UIKit, and portable executables. The repository starts at hand-written
assembly and then compares the same Apple platform APIs from C, Objective-C,
Rust, Swift, and SwiftUI.

## Repository layout

- `alert/` contains minimal macOS `NSAlert` applications in assembly, C,
  Objective-C, Rust, and Swift. The assembly version writes its complete x86_64
  Mach-O executable directly with NASM instead of using the system linker.
- `window/` contains complete macOS window applications. The C version calls
  Cocoa through the Objective-C runtime, while the other versions use their
  language's usual Cocoa bindings. The Rust example also demonstrates a small
  hand-written Cocoa bridge.
- `metal/` contains graphics examples built with Apple's Metal API. The
  Objective-C, Rust, and Swift examples open a Cocoa window and render a
  rainbow triangle with vertex and fragment shaders.
- `ios/` contains equivalent UIKit or SwiftUI applications for C,
  Objective-C, Rust, Swift, and SwiftUI. Their build scripts target an iOS
  simulator; selected examples can also use a local provisioning configuration
  to run on a physical device.
- `hello-*.s` contains focused Mach-O experiments for arm64 and x86_64,
  including static-style binaries, dynamic libSystem calls, symbol tables, and
  ad-hoc code signing.
- `portable-executable/` builds polyglot native executables that select an ELF,
  Mach-O, or PE path at startup. It includes console hello-world and GUI alert
  examples.

## Requirements

- macOS with Xcode Command Line Tools
- NASM for the assembly examples
- Xcode's optional Metal Toolchain for the Metal examples
- Rust and the required Apple targets for the Rust examples
- A booted iOS Simulator for the simulator examples

Physical iOS devices additionally require a signing identity, provisioning
profile, and device configuration. Copy `provision.sh.example` to
`provision.sh` in an example that supports device deployment and fill in the
local values. The resulting file is ignored by version control.
