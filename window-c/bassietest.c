#include <stdio.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>

#define cls objc_getClass
#define sel sel_getUid
#define msg ((id (*)(id, SEL))objc_msgSend)
#define msg_id ((id (*)(id, SEL, id))objc_msgSend)
#define msg_bool ((id (*)(id, SEL, BOOL))objc_msgSend)
#define msg_cls ((id (*)(Class, SEL))objc_msgSend)
#define msg_cls_id ((id (*)(Class, SEL, id))objc_msgSend)

typedef double CGFloat;

typedef struct CGSize {
    CGFloat width;
    CGFloat height;
} CGSize;
typedef CGSize NSSize;

typedef struct CGRect {
    CGFloat x;
    CGFloat y;
    CGFloat width;
    CGFloat height;
} CGRect;
typedef CGRect NSRect;

typedef enum NSWindowStyleMask {
    NSWindowStyleMaskTitled = 1,
    NSWindowStyleMaskClosable = 2,
    NSWindowStyleMaskMiniaturizable = 4,
    NSWindowStyleMaskResizable = 8
} NSWindowStyleMask;

typedef enum NSBackingStoreType {
    NSBackingStoreBuffered = 2
} NSBackingStoreType;

typedef enum NSTextAlignment {
    NSTextAlignmentCenter = 1
} NSTextAlignment;

id NSString(char *string) {
    return ((id (*)(Class, SEL, char *))objc_msgSend)(cls("NSString"), sel("stringWithUTF8String:"), string);
}

Class AppDelegate;
Class WindowDelegate;

id application;
id window;
#define LABEL_SIZE 48
id label;

void windowDidResize(id self, SEL cmd) {
    NSRect windowFrame = ((NSRect (*)(id, SEL))objc_msgSend)(window, sel("frame"));
    ((id (*)(id, SEL, NSRect))objc_msgSend)(label, sel("setFrame:"), (NSRect){0, (windowFrame.height - LABEL_SIZE) / 2.f, windowFrame.width, LABEL_SIZE});
}

void applicationDidFinishLaunching(id self, SEL cmd) {
    // Create menu
    id menubar = msg_cls(cls("NSMenu"), sel("new"));
    msg_id(application, sel("setMainMenu:"), menubar);

    id menuBarItem = msg_cls(cls("NSMenuItem"), sel("new"));
    msg_id(menubar, sel("addItem:"), menuBarItem);

    id appMenu = msg_cls(cls("NSMenu"), sel("new"));
    msg_id(menuBarItem, sel("setSubmenu:"), appMenu);

    id quitMenuItem = ((id (*)(id, SEL, id, SEL, id))objc_msgSend)(msg_cls(cls("NSMenuItem"), sel("alloc")),
        sel("initWithTitle:action:keyEquivalent:"), NSString("Quit BassieTest"), sel("terminate:"), NSString("q"));
    msg_id(appMenu, sel("addItem:"), quitMenuItem);

    // Create window
    window = ((id (*)(id, SEL, NSRect, int, int, int))objc_msgSend)(
        msg_cls(cls("NSWindow"), sel("alloc")),
        sel("initWithContentRect:styleMask:backing:defer:"),
        (NSRect){0, 0, 1024, 768},
        NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable,
        NSBackingStoreBuffered,
        NO
    );
    msg_id(window, sel("setTitle:"), NSString("BassieTest"));
    msg_bool(window, sel("setTitlebarAppearsTransparent:"), YES);
    id screen = msg(window, sel("screen"));
    NSRect screenFrame = ((NSRect (*)(id, SEL))objc_msgSend)(screen, sel("frame"));
    NSRect windowFrame = ((NSRect (*)(id, SEL))objc_msgSend)(window, sel("frame"));
    CGFloat windowX = (screenFrame.width - windowFrame.width) / 2;
    CGFloat windowY = (screenFrame.height - windowFrame.height) / 2;
    ((id (*)(id, SEL, NSRect, BOOL))objc_msgSend)(window, sel("setFrame:display:"), (NSRect){windowX, windowY, windowFrame.width, windowFrame.height}, YES);
    ((id (*)(id, SEL, NSSize))objc_msgSend)(window, sel("setMinSize:"), (NSSize){320, 240});
    msg_id(window, sel("setBackgroundColor:"), ((id (*)(Class, SEL, CGFloat, CGFloat, CGFloat, CGFloat))objc_msgSend)(
        cls("NSColor"), sel("colorWithRed:green:blue:alpha:"), 0x05 / 255.f, 0x44 / 255.f, 0x5e / 255.f, 1));
    msg_id(window, sel("setDelegate:"), msg_cls(WindowDelegate, sel("new")));

    // Create label
    label = ((id (*)(id, SEL, NSRect))objc_msgSend)(msg_cls(cls("NSText"), sel("alloc")), sel("initWithFrame:"),
        (NSRect){0, (windowFrame.height - LABEL_SIZE) / 2.f, windowFrame.width, LABEL_SIZE});
    msg_id(label, sel("setString:"), NSString("Hello macOS!"));
    msg_id(label, sel("setFont:"), ((id (*)(Class, SEL, CGFloat))objc_msgSend)(cls("NSFont"), sel("systemFontOfSize:"), LABEL_SIZE));
    ((id (*)(id, SEL, NSTextAlignment))objc_msgSend)(label, sel("setAlignment:"), NSTextAlignmentCenter);
    msg_bool(label, sel("setEditable:"), NO);
    msg_bool(label, sel("setSelectable:"), NO);
    msg_bool(label, sel("setDrawsBackground:"), NO);
    msg_id(msg(window, sel("contentView")), sel("addSubview:"), label);

    ((id (*)(id, SEL, void *))objc_msgSend)(window, sel("makeKeyAndOrderFront:"), nil);
}

BOOL applicationShouldTerminateAfterLastWindowClosed(id self, SEL cmd) {
    return YES;
}

int main(void) {
    // Register classes
    WindowDelegate = objc_allocateClassPair(cls("NSObject"), "WindowDelegate", 0);
    class_addMethod(WindowDelegate, sel("windowDidResize:"), (IMP)windowDidResize, "v@:");
    objc_registerClassPair(WindowDelegate);

    AppDelegate = objc_allocateClassPair(cls("NSObject"), "AppDelegate", 0);
    class_addMethod(AppDelegate, sel("applicationDidFinishLaunching:"), (IMP)applicationDidFinishLaunching, "v@:");
    class_addMethod(AppDelegate, sel("applicationShouldTerminateAfterLastWindowClosed:"), (IMP)applicationShouldTerminateAfterLastWindowClosed, "B@:");
    objc_registerClassPair(AppDelegate);

    // Start application
    application = msg_cls(cls("NSApplication"), sel("sharedApplication"));
    msg_id(application, sel("setDelegate:"), msg_cls(AppDelegate, sel("new")));
    msg(application, sel("run"));
    return EXIT_SUCCESS;
}
