#!/bin/sh
name=BassieTest
set -e
mkdir -p $name.app/Contents/MacOS
cargo build
cp target/debug/bassietest $name.app/Contents/MacOS/$name
cp target/Info.plist $name.app/Contents
./$name.app/Contents/MacOS/$name
