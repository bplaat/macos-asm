#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

// MARK: Objective-C runtime headers
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
extern void *objc_msgSend(id self, SEL sel, ...);
#ifndef __arm64__
extern void objc_msgSend_stret(void *ret, id self, SEL sel, ...);
#endif
extern void object_setInstanceVariable(id obj, const char *name, void *value);
extern void object_getInstanceVariable(id obj, const char *name, void **outValue);
struct objc_super {
    id receiver;
    Class super_class;
};
extern void objc_msgSendSuper(struct objc_super *super, SEL sel, ...);

#define cls objc_getClass
#define sel sel_registerName
#define msg ((id (*)(id, SEL))objc_msgSend)
#define msg_id ((id (*)(id, SEL, id))objc_msgSend)
#define msg_int ((id (*)(id, SEL, int))objc_msgSend)
#define msg_rect ((id (*)(id, SEL, NSRect))objc_msgSend)
#define msg_cls ((id (*)(Class, SEL))objc_msgSend)
#define msg_cls_str ((id (*)(Class, SEL, char *))objc_msgSend)
#define msg_cls_double ((id (*)(Class, SEL, double))objc_msgSend)
#define msg_cls_double_double_double_double ((id (*)(Class, SEL, double, double, double, double))objc_msgSend)

#ifdef __arm64__
#define msg_ret_rect ((NSRect (*)(id, SEL))objc_msgSend)
#else
#define msg_ret_rect(a, b) ({ \
    NSRect tmp; \
    ((void (*)(NSRect *, id, SEL))objc_msgSend_stret)(&tmp, a, b); \
    tmp; \
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

id NSString(char *string) {
    return msg_cls_str(cls("NSString"), sel("stringWithUTF8String:"), string);
}

extern int UIApplicationMain(int argc, char **argv, id principalClassName, id delegateClassName);
extern void NSLog(char *format, ...);

// MARK: ViewController
void view_controller_view_did_load(id self, SEL cmd) {
    (void)cmd;
    struct objc_super super = { self, cls("UIViewController") };
    objc_msgSendSuper(&super, sel("viewDidLoad"));

    id view = msg(self, sel("view"));
    msg_id(view, sel("setBackgroundColor:"), msg_cls_double_double_double_double(cls("UIColor"), sel("colorWithRed:green:blue:alpha:"), 0x05 / 255.0, 0x44 / 255.0, 0x5e / 255.0, 1));

    id label = msg_cls(cls("UILabel"), sel("new"));
    object_setInstanceVariable(self, "_label", label);
    msg_id(label, sel("setText:"), NSString("Hello iOS!"));
    msg_id(label, sel("setFont:"), msg_cls_double(cls("UIFont"), sel("systemFontOfSize:"), 48));
    msg_int(label, sel("setTextAlignment:"), NSTextAlignmentCenter);
    msg_id(view, sel("addSubview:"), label);
}

void view_controller_view_will_layout_subviews(id self, SEL cmd) {
    (void)cmd;
    struct objc_super super = { self, cls("UIViewController") };
    objc_msgSendSuper(&super, sel("viewWillLayoutSubviews"));

    id label;
    object_getInstanceVariable(self, "_label", (void **)&label);
    msg_rect(label, sel("setFrame:"), msg_ret_rect(msg(self, sel("view")), sel("bounds")));
}

// MARK: AppDelegate
bool app_delegate_application_did_finish_launching_with_options(id self, SEL cmd, id application, id launch_options) {
    (void)self;
    (void)cmd;
    (void)application;
    (void)launch_options;

    id window = window = msg_rect(msg_cls(cls("UIWindow"), sel("alloc")), sel("initWithFrame:"), msg_ret_rect(msg(cls("UIScreen"), sel("mainScreen")), sel("bounds")));
    msg_int(window, sel("setOverrideUserInterfaceStyle:"), UIUserInterfaceStyleDark);
    msg_id(window, sel("setRootViewController:"), msg(cls("ViewController"), sel("new")));
    msg(window, sel("makeKeyAndVisible"));

    NSLog(NSString("Hello iOS!\n"));
    return true;
}

// MARK: Main
int main(int argc, char **argv) {
    // Register classes
    Class ViewController = objc_allocateClassPair(cls("UIViewController"), "ViewController", 0);
    class_addIvar(ViewController, "_label", sizeof(id), log2(sizeof(id)), "^v");
    class_addMethod(ViewController, sel("viewDidLoad"), (IMP)view_controller_view_did_load, "v@:");
    class_addMethod(ViewController, sel("viewWillLayoutSubviews"), (IMP)view_controller_view_will_layout_subviews, "v@:");
    objc_registerClassPair(ViewController);

    Class AppDelegate = objc_allocateClassPair(cls("NSObject"), "AppDelegate", 0);
    class_addMethod(AppDelegate, sel("application:didFinishLaunchingWithOptions:"), (IMP)app_delegate_application_did_finish_launching_with_options, "B@:@");
    objc_registerClassPair(AppDelegate);

    // Start application
    return UIApplicationMain(argc, argv, NULL, NSString("AppDelegate"));
}
