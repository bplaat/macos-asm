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

// Objective-C BOOL is C bool on arm64 and signed char on x86_64.
#if __OBJC_BOOL_IS_BOOL
typedef bool BOOL;
#define OBJC_BOOL_ENCODING "B"
#else
typedef signed char BOOL;
#define OBJC_BOOL_ENCODING "c"
#endif

#define YES ((BOOL)1)
#define NO ((BOOL)0)

extern Class objc_getClass(const char* name);
extern Class objc_allocateClassPair(Class superclass, const char* name, size_t extraBytes);
extern BOOL class_addIvar(Class cls, const char* name, size_t size, uint8_t alignment, const char* types);
extern BOOL class_addMethod(Class cls, SEL name, IMP imp, const char* types);
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
#define msg_void_integer ((void (*)(id, SEL, NSInteger))objc_msgSend)
#define msg_void_rect ((void (*)(id, SEL, NSRect))objc_msgSend)
#define msg_init_rect ((id (*)(id, SEL, NSRect))objc_msgSend)
#define msg_cls ((id (*)(Class, SEL))objc_msgSend)
#define msg_cls_str ((id (*)(Class, SEL, const char*))objc_msgSend)
#define msg_cls_double ((id (*)(Class, SEL, double))objc_msgSend)
#define msg_cls_double_double_double_double ((id (*)(Class, SEL, double, double, double, double))objc_msgSend)
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

// MARK: UIKit headers
typedef struct NSRect {
    double x;
    double y;
    double width;
    double height;
} NSRect;

#define UIUserInterfaceStyleDark 2

#define NSTextAlignmentCenter 1

static id ns_string(const char* string) {
    return msg_cls_str(cls("NSString"), sel("stringWithUTF8String:"), string);
}

extern int UIApplicationMain(int argc, char** argv, id principalClassName, id delegateClassName);
extern void NSLog(char* format, ...);

// MARK: ViewController
void view_controller_view_did_load(id self, SEL cmd) {
    (void)cmd;
    struct objc_super super = {self, cls("UIViewController")};
    msg_super_void(&super, sel("viewDidLoad"));

    id view = msg_id0(self, sel("view"));
    msg_void_id(view, sel("setBackgroundColor:"),
                msg_cls_double_double_double_double(cls("UIColor"), sel("colorWithRed:green:blue:alpha:"), 0x05 / 255.0,
                                                    0x44 / 255.0, 0x5e / 255.0, 1));

    id label = msg_cls(cls("UILabel"), sel("new"));
    id old_label = NULL;
    object_getInstanceVariable(self, "_label", (void**)&old_label);
    if (old_label != NULL) {
        msg_void(old_label, sel("release"));
    }
    object_setInstanceVariable(self, "_label", label);
    msg_void_id(label, sel("setText:"), ns_string("Hello iOS!"));
    msg_void_id(label, sel("setFont:"), msg_cls_double(cls("UIFont"), sel("systemFontOfSize:"), 48));
    msg_void_integer(label, sel("setTextAlignment:"), NSTextAlignmentCenter);
    msg_void_id(view, sel("addSubview:"), label);
}

void view_controller_view_will_layout_subviews(id self, SEL cmd) {
    (void)cmd;
    struct objc_super super = {self, cls("UIViewController")};
    msg_super_void(&super, sel("viewWillLayoutSubviews"));

    id label;
    object_getInstanceVariable(self, "_label", (void**)&label);
    msg_void_rect(label, sel("setFrame:"), msg_ret_rect(msg_id0(self, sel("view")), sel("bounds")));
}

void view_controller_dealloc(id self, SEL cmd) {
    (void)cmd;
    id label = NULL;
    object_getInstanceVariable(self, "_label", (void**)&label);
    if (label != NULL) {
        msg_void(label, sel("release"));
    }
    struct objc_super super = {self, cls("UIViewController")};
    msg_super_void(&super, sel("dealloc"));
}

// MARK: AppDelegate
BOOL app_delegate_application_did_finish_launching_with_options(id self, SEL cmd, id application, id launch_options) {
    (void)cmd;
    (void)application;
    (void)launch_options;

    id window = msg_init_rect(msg_cls(cls("UIWindow"), sel("alloc")), sel("initWithFrame:"),
                              msg_ret_rect(msg_id0(cls("UIScreen"), sel("mainScreen")), sel("bounds")));
    id old_window = NULL;
    object_getInstanceVariable(self, "_window", (void**)&old_window);
    if (old_window != NULL) {
        msg_void(old_window, sel("release"));
    }
    object_setInstanceVariable(self, "_window", window);
    msg_void_integer(window, sel("setOverrideUserInterfaceStyle:"), UIUserInterfaceStyleDark);
    id view_controller = msg_cls(cls("ViewController"), sel("new"));
    msg_void_id(window, sel("setRootViewController:"), view_controller);
    msg_void(view_controller, sel("release"));
    msg_void(window, sel("makeKeyAndVisible"));

    NSLog(ns_string("Hello iOS!\n"));
    return YES;
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
int main(int argc, char** argv) {
    void* pool = objc_autoreleasePoolPush();

    // Register classes
    Class ViewController = objc_allocateClassPair(cls("UIViewController"), "ViewController", 0);
    class_addIvar(ViewController, "_label", sizeof(id), (uint8_t)__builtin_ctzll(_Alignof(id)), "@");
    class_addMethod(ViewController, sel("viewDidLoad"), (IMP)view_controller_view_did_load, "v@:");
    class_addMethod(ViewController, sel("viewWillLayoutSubviews"), (IMP)view_controller_view_will_layout_subviews,
                    "v@:");
    class_addMethod(ViewController, sel("dealloc"), (IMP)view_controller_dealloc, "v@:");
    objc_registerClassPair(ViewController);

    Class AppDelegate = objc_allocateClassPair(cls("NSObject"), "AppDelegate", 0);
    class_addIvar(AppDelegate, "_window", sizeof(id), (uint8_t)__builtin_ctzll(_Alignof(id)), "@");
    class_addMethod(AppDelegate, sel("application:didFinishLaunchingWithOptions:"),
                    (IMP)app_delegate_application_did_finish_launching_with_options, OBJC_BOOL_ENCODING "@:@@");
    class_addMethod(AppDelegate, sel("dealloc"), (IMP)app_delegate_dealloc, "v@:");
    objc_registerClassPair(AppDelegate);

    // Start application
    int result = UIApplicationMain(argc, argv, NULL, ns_string("AppDelegate"));
    objc_autoreleasePoolPop(pool);
    return result;
}
