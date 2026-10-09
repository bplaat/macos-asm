NAME := $(shell plutil -extract CFBundleExecutable raw Info.plist)
MINIMUM_VERSION := $(shell plutil -extract LSMinimumSystemVersion raw Info.plist)
APP := $(NAME).app
BINARY := $(APP)/Contents/MacOS/$(NAME)

.PHONY: all clean run
.DELETE_ON_ERROR:

all: $(BINARY)

$(APP)/Contents/Resources/default.metallib: src/shaders.metal $(wildcard src/*.h) Info.plist
	mkdir -p target "$(APP)/Contents/Resources"
	xcrun --sdk macosx metal -mmacosx-version-min="$(MINIMUM_VERSION)" -c src/shaders.metal -o target/shaders.air
	xcrun --sdk macosx metallib target/shaders.air -o "$(APP)/Contents/Resources/default.metallib"

$(BINARY): $(wildcard src/* src/assets/*) Info.plist Entitlements.plist $(APP)/Contents/Resources/default.metallib
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	swiftc -target "$(shell uname -m)-apple-macosx$(MINIMUM_VERSION)" -import-objc-header src/shader_types.h \
		src/main.swift -o "$(BINARY)"
	plutil -convert binary1 -o "$(APP)/Contents/Info.plist" Info.plist
	codesign --force --sign - --entitlements Entitlements.plist --options runtime "$(APP)"

run: all
	"$(BINARY)"

clean:
	rm -rf target "$(APP)"
