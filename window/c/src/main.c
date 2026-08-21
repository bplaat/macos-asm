#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

// MARK: Objective-C runtime headers
typedef void* id;
typedef id Class;
typedef id SEL;
typedef id (*IMP)(id self, SEL selector, ...);
typedef void* Ivar;
typedef long NSInteger;
typedef unsigned long NSUInteger;

extern Class objc_getClass(const char* name);
extern Class objc_allocateClassPair(Class superclass, const char* name, size_t extraBytes);
extern bool class_addIvar(Class cls, const char* name, size_t size, uint8_t alignment, const char* types);
extern bool class_addMethod(Class cls, SEL name, IMP imp, const char* types);
extern void objc_registerClassPair(Class cls);
extern SEL sel_registerName(const char* name);
extern void objc_msgSend(void);
#ifndef __arm64__
extern void objc_msgSend_stret(void);
#endif
extern Ivar object_setInstanceVariable(id obj, const char* name, void* value);
extern Ivar object_getInstanceVariable(id obj, const char* name, void** outValue);
struct objc_super {
    id receiver;
    Class super_class;
};
extern void objc_msgSendSuper(void);
extern void* objc_autoreleasePoolPush(void);
extern void objc_autoreleasePoolPop(void* pool);

#define cls objc_getClass
#define sel sel_registerName
#define msg_id0 ((id (*)(id, SEL))objc_msgSend)
#define msg_void ((void (*)(id, SEL))objc_msgSend)
#define msg_void_id ((void (*)(id, SEL, id))objc_msgSend)
#define msg_void_bool ((void (*)(id, SEL, bool))objc_msgSend)
#define msg_void_rect_id ((void (*)(id, SEL, NSRect, id))objc_msgSend)
#define msg_void_size ((void (*)(id, SEL, NSSize))objc_msgSend)
#define msg_void_rect_bool ((void (*)(id, SEL, NSRect, bool))objc_msgSend)
#define msg_bool_integer ((bool (*)(id, SEL, NSInteger))objc_msgSend)
#define msg_bool_id ((bool (*)(id, SEL, id))objc_msgSend)
#define msg_id_sel_id ((id (*)(id, SEL, id, SEL, id))objc_msgSend)
#define msg_rect_uint_uint_bool ((id (*)(id, SEL, NSRect, NSUInteger, NSUInteger, bool))objc_msgSend)
#define msg_cls ((id (*)(Class, SEL))objc_msgSend)
#define msg_cls_id ((id (*)(Class, SEL, id))objc_msgSend)
#define msg_cls_str ((id (*)(Class, SEL, const char*))objc_msgSend)
#define msg_cls_double ((id (*)(Class, SEL, double))objc_msgSend)
#define msg_cls_double_double_double_double ((id (*)(Class, SEL, double, double, double, double))objc_msgSend)
#define msg_cls_id_id_uint ((id (*)(Class, SEL, id, id, NSUInteger))objc_msgSend)
#define msg_id_ret_size ((NSSize (*)(id, SEL, id))objc_msgSend)
#define msg_super_void ((void (*)(struct objc_super*, SEL))objc_msgSendSuper)

#ifdef __arm64__
#define msg_ret_rect ((NSRect (*)(id, SEL))objc_msgSend)
#else
#define msg_ret_rect(a, b)                                            \
    ({                                                                \
        NSRect tmp;                                                   \
        ((void (*)(NSRect*, id, SEL))objc_msgSend_stret)(&tmp, a, b); \
        tmp;                                                          \
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

static id ns_string(const char* string) {
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

    id text = ns_string("Hello macOS!");

    id keys[] = {NSFontAttributeName, NSForegroundColorAttributeName};
    id values[] = {
        msg_cls_double(cls("NSFont"), sel("systemFontOfSize:"), 48),
        msg_id0(cls("NSColor"), sel("whiteColor")),
    };
    id attributes = msg_cls_id_id_uint(cls("NSDictionary"), sel("dictionaryWithObjects:forKeys:count:"), values, keys,
                                       sizeof(keys) / sizeof(id));

    NSSize size = msg_id_ret_size(text, sel("sizeWithAttributes:"), attributes);
    NSRect frame = msg_ret_rect(self, sel("frame"));
    NSRect rect = {(frame.width - size.width) / 2, (frame.height - size.height) / 2, size.width, size.height};
    msg_void_rect_id(text, sel("drawInRect:withAttributes:"), rect, attributes);
}

// MARK: AppDelegate
void app_delegate_did_finish_loading(id self, SEL cmd, id notification) {
    (void)self;
    (void)cmd;
    (void)notification;

    // Create menu
    id menubar = msg_cls(cls("NSMenu"), sel("new"));
    msg_void_id(NSApp, sel("setMainMenu:"), menubar);
    msg_void(menubar, sel("release"));

    id menu_bar_item = msg_cls(cls("NSMenuItem"), sel("new"));
    msg_void_id(menubar, sel("addItem:"), menu_bar_item);
    msg_void(menu_bar_item, sel("release"));

    id app_menu = msg_cls(cls("NSMenu"), sel("new"));
    msg_void_id(menu_bar_item, sel("setSubmenu:"), app_menu);
    msg_void(app_menu, sel("release"));

    id about_menu_item =
        msg_id_sel_id(msg_cls(cls("NSMenuItem"), sel("alloc")), sel("initWithTitle:action:keyEquivalent:"),
                      ns_string("About BassieTest"), sel("openAbout:"), ns_string(""));
    msg_void_id(app_menu, sel("addItem:"), about_menu_item);
    msg_void(about_menu_item, sel("release"));

    msg_void_id(app_menu, sel("addItem:"), msg_cls(cls("NSMenuItem"), sel("separatorItem")));

    id quit_menu_item =
        msg_id_sel_id(msg_cls(cls("NSMenuItem"), sel("alloc")), sel("initWithTitle:action:keyEquivalent:"),
                      ns_string("Quit BassieTest"), sel("terminate:"), ns_string("q"));
    msg_void_id(app_menu, sel("addItem:"), quit_menu_item);
    msg_void(quit_menu_item, sel("release"));

    // Create window
    id window = msg_rect_uint_uint_bool(msg_cls(cls("NSWindow"), sel("alloc")),
                                        sel("initWithContentRect:styleMask:backing:defer:"), (NSRect){0, 0, 1024, 768},
                                        NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable,
                                        NSBackingStoreBuffered, false);
    id old_window = NULL;
    object_getInstanceVariable(self, "_window", (void**)&old_window);
    if (old_window != NULL) {
        msg_void(old_window, sel("release"));
    }
    object_setInstanceVariable(self, "_window", window);
    msg_void_bool(window, sel("setReleasedWhenClosed:"), false);
    msg_void_id(window, sel("setTitle:"), ns_string("BassieTest"));
    msg_void_bool(window, sel("setTitlebarAppearsTransparent:"), true);
    msg_void_id(window, sel("setAppearance:"),
                msg_cls_id(cls("NSAppearance"), sel("appearanceNamed:"), NSAppearanceNameDarkAqua));
    id screen = msg_id0(window, sel("screen"));
    if (screen != NULL) {
        NSRect screen_frame = msg_ret_rect(screen, sel("frame"));
        NSRect window_frame = msg_ret_rect(window, sel("frame"));
        double window_x = (screen_frame.width - window_frame.width) / 2;
        double window_y = (screen_frame.height - window_frame.height) / 2;
        msg_void_rect_bool(window, sel("setFrame:display:"),
                           (NSRect){window_x, window_y, window_frame.width, window_frame.height}, true);
    }
    msg_void_size(window, sel("setMinSize:"), (NSSize){320, 240});
    msg_void_id(window, sel("setBackgroundColor:"),
                msg_cls_double_double_double_double(cls("NSColor"), sel("colorWithRed:green:blue:alpha:"), 0x05 / 255.0,
                                                    0x44 / 255.0, 0x5e / 255.0, 1));
    (void)msg_bool_id(window, sel("setFrameAutosaveName:"), ns_string("window"));

    // Create canvas
    id canvas_view = msg_cls(cls("CanvasView"), sel("new"));
    msg_void_id(window, sel("setContentView:"), canvas_view);
    msg_void(canvas_view, sel("release"));

    // Show window
    (void)msg_bool_integer(NSApp, sel("setActivationPolicy:"), NSApplicationActivationPolicyRegular);
    msg_void_bool(NSApp, sel("activateIgnoringOtherApps:"), true);
    msg_void_id(window, sel("makeKeyAndOrderFront:"), NULL);
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
    msg_void_id(NSApp, sel("orderFrontStandardAboutPanel:"), NULL);
}

void app_delegate_dealloc(id self, SEL cmd) {
    (void)cmd;
    id window = NULL;
    object_getInstanceVariable(self, "_window", (void**)&window);
    if (window != NULL) {
        msg_void(window, sel("release"));
    }
    struct objc_super super = {self, cls("NSObject")};
    msg_super_void(&super, sel("dealloc"));
}

// MARK: Main
int main(void) {
    void* pool = objc_autoreleasePoolPush();

    // Register classes
    Class CanvasView = objc_allocateClassPair(cls("NSView"), "CanvasView", 0);
    class_addMethod(CanvasView, sel("drawRect:"), (IMP)canvas_view_draw_rect, "v@:{NSRect={CGPoint=dd}{CGSize=dd}}");
    objc_registerClassPair(CanvasView);

    Class AppDelegate = objc_allocateClassPair(cls("NSObject"), "AppDelegate", 0);
    class_addIvar(AppDelegate, "_window", sizeof(id), (uint8_t)__builtin_ctzll(_Alignof(id)), "@");
    class_addMethod(AppDelegate, sel("applicationDidFinishLaunching:"), (IMP)app_delegate_did_finish_loading, "v@:@");
    class_addMethod(AppDelegate, sel("applicationShouldTerminateAfterLastWindowClosed:"),
                    (IMP)app_should_terminate_after_last_window_closed, "B@:@");
    class_addMethod(AppDelegate, sel("openAbout:"), (IMP)open_about, "v@:@");
    class_addMethod(AppDelegate, sel("dealloc"), (IMP)app_delegate_dealloc, "v@:");
    objc_registerClassPair(AppDelegate);

    // Start application
    id app = msg_cls(cls("NSApplication"), sel("sharedApplication"));
    id delegate = msg_cls(AppDelegate, sel("new"));
    msg_void_id(app, sel("setDelegate:"), delegate);
    msg_void(app, sel("run"));
    msg_void(delegate, sel("release"));
    objc_autoreleasePoolPop(pool);
    return EXIT_SUCCESS;
}
