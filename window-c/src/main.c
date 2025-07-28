#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>

// MARK: Objective-C runtime headers
typedef void *id;
typedef id Class;
typedef id SEL;
typedef id IMP;

extern Class objc_getClass(const char *name);
extern Class objc_allocateClassPair(Class superclass, const char *name, size_t extraBytes);
extern void class_addMethod(Class cls, SEL name, IMP imp, const char *types);
extern void objc_registerClassPair(Class cls);
extern SEL sel_registerName(const char *name);
extern void *objc_msgSend(id self, SEL sel, ...);
#ifndef __arm64__
extern void objc_msgSend_stret(void *ret, id self, SEL sel, ...);
#endif

#define cls objc_getClass
#define sel sel_registerName
#define msg ((id (*)(id, SEL))objc_msgSend)
#define msg_id ((id (*)(id, SEL, id))objc_msgSend)
#define msg_bool ((id (*)(id, SEL, bool))objc_msgSend)
#define msg_int ((id (*)(id, SEL, int))objc_msgSend)
#define msg_rect ((id (*)(id, SEL, NSRect))objc_msgSend)
#define msg_rect_id ((id (*)(id, SEL, NSRect, id))objc_msgSend)
#define msg_size ((id (*)(id, SEL, NSSize))objc_msgSend)
#define msg_rect_bool ((id (*)(id, SEL, NSRect, bool))objc_msgSend)
#define msg_id_sel_id ((id (*)(id, SEL, id, SEL, id))objc_msgSend)
#define msg_rect_int_int_int ((id (*)(id, SEL, NSRect, int, int, int))objc_msgSend)
#define msg_cls ((id (*)(Class, SEL))objc_msgSend)
#define msg_cls_id ((id (*)(Class, SEL, id))objc_msgSend)
#define msg_cls_str ((id (*)(Class, SEL, char *))objc_msgSend)
#define msg_cls_double ((id (*)(Class, SEL, double))objc_msgSend)
#define msg_cls_double_double_double_double ((id (*)(Class, SEL, double, double, double, double))objc_msgSend)
#define msg_cls_id_id_int ((id (*)(Class, SEL, id, id, int))objc_msgSend)
#define msg_id_ret_size ((NSSize (*)(id, SEL, id))objc_msgSend)

#ifdef __arm64__
#define msg_ret_rect ((NSRect (*)(id, SEL))objc_msgSend)
#else
#define msg_ret_rect(a, b) ({ \
    NSRect tmp; \
    ((void (*)(NSRect *, id, SEL))objc_msgSend_stret)(&tmp, a, b); \
    tmp; \
})
#endif

// MARK: Cocoa headers
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

#define NSApplicationActivationPolicyRegular 0

#define NSWindowStyleMaskTitled 1
#define NSWindowStyleMaskClosable 2
#define NSWindowStyleMaskMiniaturizable 4
#define NSWindowStyleMaskResizable 8

#define NSBackingStoreBuffered 2

id NSString(char *string) {
    return msg_cls_str(cls("NSString"), sel("stringWithUTF8String:"), string);
}

extern id NSApp;
extern id NSAppearanceNameDarkAqua;
extern id NSFontAttributeName;
extern id NSForegroundColorAttributeName;

// MARK: CanvasView
void canvas_view_draw_rect(id self, SEL cmd, NSRect dirtyRect) {
    (void)cmd;
    (void)dirtyRect;

    id text = NSString("Hello macOS!");

    id keys[] = { NSFontAttributeName, NSForegroundColorAttributeName };
    id values[] = {
        msg_cls_double(cls("NSFont"), sel("systemFontOfSize:"), 48),
        msg(cls("NSColor"), sel("whiteColor"))
    };
    id attributes = msg_cls_id_id_int(cls("NSDictionary"), sel("dictionaryWithObjects:forKeys:count:"), values, keys, sizeof(keys) / sizeof(id));

    NSSize size = msg_id_ret_size(text, sel("sizeWithAttributes:"), attributes);
    NSRect frame = msg_ret_rect(self, sel("frame"));
    NSRect rect = { (frame.width - size.width) / 2, (frame.height - size.height) / 2, size.width, size.height };
    msg_rect_id(text, sel("drawInRect:withAttributes:"), rect, attributes);
}

// MARK: AppDelegate
void app_delegate_did_finish_loading(id self, SEL cmd, id notification) {
    (void)self;
    (void)cmd;
    (void)notification;

    // Create menu
    id menubar = msg_cls(cls("NSMenu"), sel("new"));
    msg_cls_id(NSApp, sel("setMainMenu:"), menubar);

    id menu_bar_item = msg_cls(cls("NSMenuItem"), sel("new"));
    msg_id(menubar, sel("addItem:"), menu_bar_item);

    id app_menu = msg_cls(cls("NSMenu"), sel("new"));
    msg_id(menu_bar_item, sel("setSubmenu:"), app_menu);

    id about_menu_item = msg_id_sel_id(msg_cls(cls("NSMenuItem"), sel("alloc")),
        sel("initWithTitle:action:keyEquivalent:"), NSString("About BassieTest"), sel("openAbout:"), NSString(""));
    msg_id(app_menu, sel("addItem:"), about_menu_item);

    msg_id(app_menu, sel("addItem:"), msg_cls(cls("NSMenuItem"), sel("separatorItem")));

    id quit_menu_item = msg_id_sel_id(msg_cls(cls("NSMenuItem"), sel("alloc")),
        sel("initWithTitle:action:keyEquivalent:"), NSString("Quit BassieTest"), sel("terminate:"), NSString("q"));
    msg_id(app_menu, sel("addItem:"), quit_menu_item);

    // Create window
    id window = msg_rect_int_int_int(
        msg_cls(cls("NSWindow"), sel("alloc")),
        sel("initWithContentRect:styleMask:backing:defer:"),
        (NSRect){0, 0, 1024, 768},
        NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable,
        NSBackingStoreBuffered,
        false
    );
    msg_id(window, sel("setTitle:"), NSString("BassieTest"));
    msg_bool(window, sel("setTitlebarAppearsTransparent:"), true);
    msg_id(window, sel("setAppearance:"),  msg_cls_str(cls("NSAppearance"), sel("appearanceNamed:"), NSAppearanceNameDarkAqua));
    NSRect screen_frame = msg_ret_rect(msg(window, sel("screen")), sel("frame"));
    NSRect window_frame = msg_ret_rect(window, sel("frame"));
    double window_x = (screen_frame.width - window_frame.width) / 2;
    double window_y = (screen_frame.height - window_frame.height) / 2;
    msg_rect_bool(window, sel("setFrame:display:"), (NSRect){window_x, window_y, window_frame.width, window_frame.height}, true);
    msg_size(window, sel("setMinSize:"), (NSSize){320, 240});
    msg_id(window, sel("setBackgroundColor:"), msg_cls_double_double_double_double(
        cls("NSColor"), sel("colorWithRed:green:blue:alpha:"), 0x05 / 255.0, 0x44 / 255.0, 0x5e / 255.0, 1));
    msg_id(window, sel("setFrameAutosaveName:"), NSString("window"));

    // Create canvas
    msg_id(window, sel("setContentView:"), msg_cls(cls("CanvasView"), sel("new")));

    // Show window
    msg_int(NSApp, sel("setActivationPolicy:"), NSApplicationActivationPolicyRegular);
    msg_bool(NSApp, sel("activateIgnoringOtherApps:"), true);
    msg_id(window, sel("makeKeyAndOrderFront:"), NULL);
}

bool app_should_terminate_after_last_window_closed(id self, SEL cmd, id sender) {
    (void)self;
    (void)cmd;
    (void)sender;
    return true;
}

void open_about(id self, SEL cmd, id sender) {
    (void)self;
    (void)cmd;
    (void)sender;
    msg_cls_id(NSApp, sel("orderFrontStandardAboutPanel:"), NULL);
}

// MARK: Main
int main(void) {
    // Register classes
    Class CanvasView = objc_allocateClassPair(cls("NSView"), "CanvasView", 0);
    class_addMethod(CanvasView, sel("drawRect:"), (IMP)canvas_view_draw_rect, "v@:{NSRect={CGPoint=dd}{CGSize=dd}}");
    objc_registerClassPair(CanvasView);

    Class AppDelegate = objc_allocateClassPair(cls("NSObject"), "AppDelegate", 0);
    class_addMethod(AppDelegate, sel("applicationDidFinishLaunching:"), (IMP)app_delegate_did_finish_loading, "v@:@");
    class_addMethod(AppDelegate, sel("applicationShouldTerminateAfterLastWindowClosed:"), (IMP)app_should_terminate_after_last_window_closed, "B@:@");
    class_addMethod(AppDelegate, sel("openAbout:"), (IMP)open_about, "v@:@");
    objc_registerClassPair(AppDelegate);

    // Start application
    id app = msg_cls(cls("NSApplication"), sel("sharedApplication"));
    msg_id(app, sel("setDelegate:"), msg_cls(AppDelegate, sel("new")));
    msg(app, sel("run"));
    return EXIT_SUCCESS;
}
