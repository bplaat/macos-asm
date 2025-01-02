#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

// Objective-C runtime headers
typedef void *id;
typedef id Class;
typedef id SEL;
typedef id IMP;
extern Class objc_getClass(const char *name);
extern Class objc_allocateClassPair(Class superclass, const char *name, size_t extraBytes);
extern void class_addIvar(Class cls, const char *name, size_t size, uint8_t alignment, const char *types);
extern void class_addMethod(Class cls, SEL name, IMP imp, const char *types);
extern void objc_registerClassPair(Class cls);
extern SEL sel_registerName(const char *name);
extern void object_getInstanceVariable(id obj, const char *name, void **outValue);
extern void object_setInstanceVariable(id obj, const char *name, void *value);
extern void *objc_msgSend(id self, SEL sel, ...);

// Cocoa headers stub
#define cls objc_getClass
#define sel sel_registerName
#define msg ((id (*)(id, SEL))objc_msgSend)
#define msg_id ((id (*)(id, SEL, id))objc_msgSend)
#define msg_bool ((id (*)(id, SEL, bool))objc_msgSend)
#define msg_int ((id (*)(id, SEL, int))objc_msgSend)
#define msg_rect ((id (*)(id, SEL, NSRect))objc_msgSend)
#define msg_size ((id (*)(id, SEL, NSSize))objc_msgSend)
#define msg_rect_bool ((id (*)(id, SEL, NSRect, bool))objc_msgSend)
#define msg_id_sel_id ((id (*)(id, SEL, id, SEL, id))objc_msgSend)
#define msg_rect_int_int_int ((id (*)(id, SEL, NSRect, int, int, int))objc_msgSend)
#define msg_cls ((id (*)(Class, SEL))objc_msgSend)
#define msg_cls_id ((id (*)(Class, SEL, id))objc_msgSend)
#define msg_cls_str ((id (*)(Class, SEL, char *))objc_msgSend)
#define msg_cls_double ((id (*)(Class, SEL, double))objc_msgSend)
#define msg_cls_double_double_double_double ((id (*)(Class, SEL, double, double, double, double))objc_msgSend)
#define msg_ret_rect ((NSRect (*)(id, SEL))objc_msgSend)

typedef struct NSSize {
    double width;
    double height;
} NSSize;

typedef struct NSRect {
    double x;
    double y;
    double width;
    double height;
} NSRect;

typedef enum NSApplicationActivationPolicy {
    NSApplicationActivationPolicyRegular = 0
} NSApplicationActivationPolicy;

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
    return msg_cls_str(cls("NSString"), sel("stringWithUTF8String:"), string);
}

extern id NSApp;

// Application code
#define LABEL_SIZE 48
char *window_ivar = "window";
char *label_ivar = "label";

void applicationDidFinishLaunching(id self, SEL cmd, id notification) {
    (void)cmd;
    (void)notification;

    // Create menu
    id menubar = msg_cls(cls("NSMenu"), sel("new"));
    msg_cls_id(NSApp, sel("setMainMenu:"), menubar);

    id menuBarItem = msg_cls(cls("NSMenuItem"), sel("new"));
    msg_id(menubar, sel("addItem:"), menuBarItem);

    id appMenu = msg_cls(cls("NSMenu"), sel("new"));
    msg_id(menuBarItem, sel("setSubmenu:"), appMenu);

    id quitMenuItem = msg_id_sel_id(msg_cls(cls("NSMenuItem"), sel("alloc")),
        sel("initWithTitle:action:keyEquivalent:"), NSString("Quit BassieTest"), sel("terminate:"), NSString("q"));
    msg_id(appMenu, sel("addItem:"), quitMenuItem);

    // Create window
    id window = msg_rect_int_int_int(
        msg_cls(cls("NSWindow"), sel("alloc")),
        sel("initWithContentRect:styleMask:backing:defer:"),
        (NSRect){0, 0, 1024, 768},
        NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable,
        NSBackingStoreBuffered,
        false
    );
    object_setInstanceVariable(self, window_ivar, window);
    msg_id(window, sel("setTitle:"), NSString("BassieTest"));
    msg_bool(window, sel("setTitlebarAppearsTransparent:"), true);
    msg_id(window, sel("setAppearance:"),  msg_cls_str(cls("NSAppearance"), sel("appearanceNamed:"), NSString("NSAppearanceNameDarkAqua")));
    id screen = msg(window, sel("screen"));
    NSRect screenFrame = msg_ret_rect(screen, sel("frame"));
    NSRect windowFrame = msg_ret_rect(window, sel("frame"));
    double windowX = (screenFrame.width - windowFrame.width) / 2;
    double windowY = (screenFrame.height - windowFrame.height) / 2;
    msg_rect_bool(window, sel("setFrame:display:"), (NSRect){windowX, windowY, windowFrame.width, windowFrame.height}, true);
    msg_size(window, sel("setMinSize:"), (NSSize){320, 240});
    msg_id(window, sel("setBackgroundColor:"), msg_cls_double_double_double_double(
        cls("NSColor"), sel("colorWithRed:green:blue:alpha:"), 0x05 / 255.f, 0x44 / 255.f, 0x5e / 255.f, 1));
    msg_id(window, sel("setFrameAutosaveName:"), NSString("window"));
    msg_id(window, sel("setDelegate:"), self);

    // Create label
    windowFrame = msg_ret_rect(window, sel("frame"));
    id label = msg_rect(msg_cls(cls("NSText"), sel("alloc")), sel("initWithFrame:"),
        (NSRect){0, (windowFrame.height - LABEL_SIZE) / 2.f, windowFrame.width, LABEL_SIZE});
    object_setInstanceVariable(self, label_ivar, label);
    msg_id(label, sel("setString:"), NSString("Hello macOS!"));
    msg_id(label, sel("setFont:"), msg_cls_double(cls("NSFont"), sel("systemFontOfSize:"), LABEL_SIZE));
    msg_int(label, sel("setAlignment:"), NSTextAlignmentCenter);
    msg_bool(label, sel("setEditable:"), false);
    msg_bool(label, sel("setSelectable:"), false);
    msg_bool(label, sel("setDrawsBackground:"), false);
    msg_id(msg(window, sel("contentView")), sel("addSubview:"), label);

    // Show window
    msg_int(NSApp, sel("setActivationPolicy:"), NSApplicationActivationPolicyRegular);
    msg_bool(NSApp, sel("activateIgnoringOtherApps:"), true);
    msg_id(window, sel("makeKeyAndOrderFront:"), NULL);
}

bool applicationShouldTerminateAfterLastWindowClosed(id self, SEL cmd, id sender) {
    (void)self;
    (void)cmd;
    (void)sender;
    return true;
}

void windowDidResize(id self, SEL cmd, id notification) {
    (void)cmd;
    (void)notification;
    id window;
    object_getInstanceVariable(self, window_ivar, (void **)&window);
    id label;
    object_getInstanceVariable(self, label_ivar, (void **)&label);
    NSRect windowFrame = msg_ret_rect(window, sel("frame"));
    msg_rect(label, sel("setFrame:"), (NSRect){0, (windowFrame.height - LABEL_SIZE) / 2.f, windowFrame.width, LABEL_SIZE});
}

int main(void) {
    // Register classes
    Class AppDelegate = objc_allocateClassPair(cls("NSObject"), "AppDelegate", 0);
    class_addIvar(AppDelegate, window_ivar, sizeof(void *), log2(sizeof(void *)), "^v");
    class_addIvar(AppDelegate, label_ivar, sizeof(void *), log2(sizeof(void *)), "^v");
    class_addMethod(AppDelegate, sel("applicationDidFinishLaunching:"), (IMP)applicationDidFinishLaunching, "v@:");
    class_addMethod(AppDelegate, sel("applicationShouldTerminateAfterLastWindowClosed:"), (IMP)applicationShouldTerminateAfterLastWindowClosed, "B@:");
    class_addMethod(AppDelegate, sel("windowDidResize:"), (IMP)windowDidResize, "v@:");
    objc_registerClassPair(AppDelegate);

    // Start application
    id app = msg_cls(cls("NSApplication"), sel("sharedApplication"));
    msg_id(app, sel("setDelegate:"), msg_cls(AppDelegate, sel("new")));
    msg(app, sel("run"));
    return EXIT_SUCCESS;
}
