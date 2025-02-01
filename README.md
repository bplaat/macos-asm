# macOS Assembly Examples

My journey to create valid macOS MACH-O binaries in pure assembly and some other macOS and iOS programs

## Getting Started
You need to install Xcode Command Line Tools, nasm, a Rust toolchain and [bob](https://github.com/bplaat/crates/tree/master/bin/bob) to build the examples.

```sh
xcode-select --install
brew install nasm
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install --git https://github.com/bplaat/crates bob
```
