NAME := $(shell plutil -extract CFBundleExecutable raw Info.plist)
MINIMUM_VERSION := $(shell plutil -extract LSMinimumSystemVersion raw Info.plist)
APP := $(NAME).app
BINARY := $(APP)/Contents/MacOS/$(NAME)

.PHONY: all clean run
.DELETE_ON_ERROR:

all: $(BINARY)

target/default.metallib: src/shaders.metal src/shader_types.h Info.plist
	mkdir -p target
	xcrun --sdk macosx metal -mmacosx-version-min=$(MINIMUM_VERSION) -c src/shaders.metal -o target/shaders.air
	xcrun --sdk macosx metallib target/shaders.air -o $@

$(BINARY): src/main.m $(wildcard src/*.h src/assets/*.png) target/default.metallib Info.plist Entitlements.plist
	mkdir -p "$(APP)/Contents/MacOS"
	clang -x objective-c -std=c23 --embed-dir=target --embed-dir=src/assets -fobjc-arc \
		-mmacosx-version-min=$(MINIMUM_VERSION) -Wall -Wextra -Werror src/main.m \
		-framework Cocoa -framework ImageIO -framework Metal -framework MetalKit \
		-framework QuartzCore -o "$@"
	plutil -convert binary1 -o "$(APP)/Contents/Info.plist" Info.plist
	codesign --force --sign - --entitlements Entitlements.plist --options runtime "$(APP)"

run: all
	"$(BINARY)"

clean:
	rm -rf target "$(APP)"
