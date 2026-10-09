NAME := $(shell plutil -extract CFBundleExecutable raw Info.plist)
APP := $(NAME).app
BINARY := $(APP)/Contents/MacOS/$(NAME)

.PHONY: all clean run
.DELETE_ON_ERROR:

all: $(BINARY)

$(BINARY): alert.s Info.plist Entitlements.plist
	mkdir -p "$(APP)/Contents/MacOS"
	nasm -f bin alert.s -o "$(BINARY)"
	chmod +x "$(BINARY)"
	plutil -convert binary1 -o "$(APP)/Contents/Info.plist" Info.plist
	codesign --force --sign - --entitlements Entitlements.plist --options runtime "$(APP)"

run: all
	open "$(APP)"

clean:
	rm -rf "$(APP)"
