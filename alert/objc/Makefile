NAME := $(shell plutil -extract CFBundleExecutable raw Info.plist)
MINIMUM_VERSION := $(shell plutil -extract LSMinimumSystemVersion raw Info.plist)
APP := $(NAME).app
BINARY := $(APP)/Contents/MacOS/$(NAME)

.PHONY: all clean run
.DELETE_ON_ERROR:

all: $(BINARY)

$(BINARY): $(wildcard src/* src/assets/*) Info.plist Entitlements.plist
	mkdir -p "$(APP)/Contents/MacOS"
	clang -x objective-c -fobjc-arc -mmacosx-version-min="$(MINIMUM_VERSION)" -Wall -Wextra -Werror \
		src/main.m -framework Cocoa -o "$(BINARY)"
	plutil -convert binary1 -o "$(APP)/Contents/Info.plist" Info.plist
	codesign --force --sign - --entitlements Entitlements.plist --options runtime "$(APP)"

run: all
	open "$(APP)"

clean:
	rm -rf "$(APP)"
