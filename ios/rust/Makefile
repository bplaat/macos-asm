NAME := $(shell plutil -extract CFBundleExecutable raw Info.plist)
BUNDLE_ID := $(shell plutil -extract CFBundleIdentifier raw Info.plist)
APP := $(NAME).app
BINARY := $(APP)/$(NAME)

.PHONY: all clean run
.DELETE_ON_ERROR:

all: $(BINARY)

$(BINARY): $(wildcard src/* src/assets/*) Cargo.toml Cargo.lock Info.plist
	mkdir -p "$(APP)"
	IPHONEOS_DEPLOYMENT_TARGET=15.0 cargo build --target aarch64-apple-ios-sim
	cp target/aarch64-apple-ios-sim/debug/bassietest "$(BINARY)"
	plutil -convert binary1 -o "$(APP)/Info.plist" Info.plist

run: all
	xcrun simctl install booted "$(APP)"
	xcrun simctl launch --console booted "$(BUNDLE_ID)"

clean:
	rm -rf target "$(APP)"
