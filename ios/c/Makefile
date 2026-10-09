NAME := $(shell plutil -extract CFBundleExecutable raw Info.plist)
BUNDLE_ID := $(shell plutil -extract CFBundleIdentifier raw Info.plist)
SDK := $(shell xcrun --sdk iphonesimulator --show-sdk-path)
APP := $(NAME).app
BINARY := $(APP)/$(NAME)

.PHONY: all clean run
.DELETE_ON_ERROR:

all: $(BINARY)

$(BINARY): $(wildcard src/* src/assets/*) Info.plist
	mkdir -p "$(APP)"
	clang -Wall -Wextra -Werror -Wno-cast-function-type-mismatch \
		--target=arm64-apple-ios15-simulator src/main.c \
		-isysroot "$(SDK)" \
		-framework Foundation -framework UIKit -o "$(BINARY)"
	plutil -convert binary1 -o "$(APP)/Info.plist" Info.plist

run: all
	xcrun simctl install booted "$(APP)"
	xcrun simctl launch --console booted "$(BUNDLE_ID)"

clean:
	rm -rf "$(APP)"
