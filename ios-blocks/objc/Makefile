NAME := $(shell plutil -extract CFBundleExecutable raw Info.plist)
BUNDLE_ID := $(shell plutil -extract CFBundleIdentifier raw Info.plist)
SDK := $(shell xcrun --sdk iphonesimulator --show-sdk-path)
APP := $(NAME).app
BINARY := $(APP)/$(NAME)

.PHONY: all clean run
.DELETE_ON_ERROR:

all: $(BINARY)

target/default.metallib: src/shaders.metal $(wildcard src/*.h)
	mkdir -p target
	xcrun --sdk iphonesimulator metal -c src/shaders.metal -o target/shaders.air
	xcrun --sdk iphonesimulator metallib target/shaders.air -o $@

$(BINARY): $(wildcard src/* src/assets/*) Info.plist target/default.metallib
	mkdir -p "$(APP)"
	clang -x objective-c -std=c23 --embed-dir=target --embed-dir=src/assets -fobjc-arc -Wall -Wextra -Werror \
		--target=arm64-apple-ios15-simulator \
		-isysroot "$(SDK)" \
		-framework Foundation -framework UIKit -framework CoreGraphics -framework ImageIO \
		-framework Metal -framework MetalKit -framework QuartzCore \
		src/main.m -o "$(BINARY)"
	plutil -convert binary1 -o "$(APP)/Info.plist" Info.plist

run: all
	xcrun simctl install booted "$(APP)"
	xcrun simctl launch --console booted "$(BUNDLE_ID)"

clean:
	rm -rf target "$(APP)"
