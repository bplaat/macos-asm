NAME := $(shell plutil -extract CFBundleExecutable raw Info.plist)
MINIMUM_VERSION := $(shell plutil -extract LSMinimumSystemVersion raw Info.plist)
APP := $(NAME).app
BINARY := $(APP)/Contents/MacOS/$(NAME)

.PHONY: all clean run
.DELETE_ON_ERROR:

all: $(BINARY)

$(BINARY): $(wildcard src/* src/assets/*) Info.plist Entitlements.plist
	mkdir -p "$(APP)/Contents/MacOS"
	clang -std=c23 -mmacosx-version-min="$(MINIMUM_VERSION)" -Wall -Wextra -Werror \
		-Wno-cast-function-type-mismatch -Wno-deprecated-declarations \
		src/main.c -framework Cocoa -framework OpenGL \
		-o "$(BINARY)"
	plutil -convert binary1 -o "$(APP)/Contents/Info.plist" Info.plist
	codesign --force --sign - --entitlements Entitlements.plist --options runtime "$(APP)"

run: all
	"$(BINARY)"

clean:
	rm -rf "$(APP)"
