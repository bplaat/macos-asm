#include <stdio.h>
#include <stdlib.h>
#include <objc/runtime.h>
#include <objc/message.h>

#define cls objc_getClass
#define sel sel_getUid
#define msg ((id (*)(id, SEL))objc_msgSend)
#define msg_id ((id (*)(id, SEL, id))objc_msgSend)
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

id NSString(char *string) {
    return ((id (*)(Class, SEL, char *))objc_msgSend)(cls("NSString"), sel("stringWithUTF8String:"), string);
}

id application;
id window;

void applicationDidFinishLaunching(id self, SEL cmd) {
    // Create menu
    id menubar = msg(msg_cls(cls("NSMenu"), sel("alloc")), sel("init"));
    msg_id(application, sel("setMainMenu:"), menubar);

    id menuBarItem = msg(msg_cls(cls("NSMenuItem"), sel("alloc")), sel("init"));
    msg_id(menubar, sel("addItem:"), menuBarItem);

    id appMenu = msg(msg_cls(cls("NSMenu"), sel("alloc")), sel("init"));
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

    id screen = msg(window, sel("screen"));
    NSRect screenFrame = ((NSRect (*)(id, SEL))objc_msgSend)(screen, sel("frame"));
    NSRect windowFrame = ((NSRect (*)(id, SEL))objc_msgSend)(window, sel("frame"));
    CGFloat windowX = (screenFrame.width - windowFrame.width) / 2;
    CGFloat windowY = (screenFrame.height - windowFrame.height) / 2;
    ((id (*)(id, SEL, NSRect, BOOL))objc_msgSend)(window, sel("setFrame:display:"), (NSRect){windowX, windowY, windowFrame.width, windowFrame.height}, YES);

    ((id (*)(id, SEL, NSSize))objc_msgSend)(window, sel("setMinSize:"), (NSSize){320, 240});
    msg_id(window, sel("setBackgroundColor:"), ((id (*)(Class, SEL, CGFloat, CGFloat, CGFloat, CGFloat))objc_msgSend)(
        cls("NSColor"), sel("colorWithRed:green:blue:alpha:"), 0, 0.5, 0.5, 1));
    ((id (*)(id, SEL, void *))objc_msgSend)(window, sel("makeKeyAndOrderFront:"), nil);
}

BOOL applicationShouldTerminateAfterLastWindowClosed(id self, SEL cmd) {
    return YES;
}

void applicationWillTerminate(id self, SEL cmd) {}

int main(void) {
    Class AppDelegate = objc_allocateClassPair(cls("NSObject"), "AppDelegate", 0);
    class_addMethod(AppDelegate, sel("applicationDidFinishLaunching:"), (IMP)applicationDidFinishLaunching, "v@:");
    class_addMethod(AppDelegate, sel("applicationShouldTerminateAfterLastWindowClosed:"), (IMP)applicationShouldTerminateAfterLastWindowClosed, "B@:");
    class_addMethod(AppDelegate, sel("applicationWillTerminate:"), (IMP)applicationWillTerminate, "v@:");
    objc_registerClassPair(AppDelegate);

    application = msg_cls(cls("NSApplication"), sel("sharedApplication"));
    id delegate = msg(msg_cls(AppDelegate, sel("alloc")), sel("init"));
    msg_id(application, sel("setDelegate:"), delegate);
    msg(application, sel("run"));
    return EXIT_SUCCESS;
}
