NAME := $(shell plutil -extract CFBundleExecutable raw Info.plist)
MINIMUM_VERSION := $(shell plutil -extract LSMinimumSystemVersion raw Info.plist)
APP := $(NAME).app
BINARY := $(APP)/Contents/MacOS/$(NAME)

.PHONY: all clean run
.DELETE_ON_ERROR:

all: $(BINARY)

target/default.metallib: src/shaders.metal $(wildcard src/*.h) Info.plist
	mkdir -p target
	xcrun --sdk macosx metal -mmacosx-version-min="$(MINIMUM_VERSION)" -c src/shaders.metal -o target/shaders.air
	xcrun --sdk macosx metallib target/shaders.air -o target/default.metallib

$(BINARY): $(wildcard src/* src/assets/*) Cargo.toml Cargo.lock Info.plist Entitlements.plist target/default.metallib
	mkdir -p "$(APP)/Contents/MacOS"
	MACOSX_DEPLOYMENT_TARGET="$(MINIMUM_VERSION)" cargo build
	cp target/debug/triangle "$(BINARY)"
	plutil -convert binary1 -o "$(APP)/Contents/Info.plist" Info.plist
	codesign --force --sign - --entitlements Entitlements.plist --options runtime "$(APP)"

run: all
	"$(BINARY)"

clean:
	rm -rf target "$(APP)"
