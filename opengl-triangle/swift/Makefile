NAME := $(shell plutil -extract CFBundleExecutable raw Info.plist)
MINIMUM_VERSION := $(shell plutil -extract LSMinimumSystemVersion raw Info.plist)
APP := $(NAME).app
BINARY := $(APP)/Contents/MacOS/$(NAME)

.PHONY: all clean run
.DELETE_ON_ERROR:

all: $(BINARY)

$(BINARY): $(wildcard src/* src/assets/*) Info.plist Entitlements.plist
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp src/shader.vert src/shader.frag "$(APP)/Contents/Resources"
	swiftc -target "$(shell uname -m)-apple-macosx$(MINIMUM_VERSION)" -Xcc -DGL_SILENCE_DEPRECATION \
		src/main.swift -o "$(BINARY)"
	plutil -convert binary1 -o "$(APP)/Contents/Info.plist" Info.plist
	codesign --force --sign - --entitlements Entitlements.plist --options runtime "$(APP)"

run: all
	"$(BINARY)"

clean:
	rm -rf "$(APP)"
