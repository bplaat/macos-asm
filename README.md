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
- `metal-triangle/` contains graphics examples built with Apple's Metal API. The C,
  Objective-C, Rust, and Swift examples open a Cocoa window and render a
  rainbow triangle with vertex and fragment shaders.
- `opengl-triangle/` contains Cocoa C, Objective-C, Rust, and Swift examples that render the
  same rainbow triangle with an OpenGL 4.1 Core context and GLSL shaders.
- `metal-blocks/objc/` renders a 64x64x64 blocks diorama with Metal. It generates
  only exposed cube faces, then draws them as instances using a mipmapped texture
  array, with opaque terrain before blended water and a full-screen sky pass.
- `opengl-blocks/objc/` renders the same generated diorama with an OpenGL 4.1 Core
  context. It uploads the visible faces once and draws opaque and translucent
  instances in separate passes, sampling one mipmapped texture array.
- `ios-blocks/objc/` ports the Metal diorama to iPhone and iPad. It keeps the
  visible-face instancing and texture array, and fits the renderer and frame counter
  to the device screen.
- `ios/` contains equivalent UIKit or SwiftUI applications for C,
  Objective-C, Rust, Swift, and SwiftUI. These examples target the iOS Simulator.
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

Run `make` to build, `make run` to launch, and `make clean` to remove build
outputs inside an example directory.
