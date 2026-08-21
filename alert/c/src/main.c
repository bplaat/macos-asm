#include <stdlib.h>

// MARK: Objective-C runtime headers
typedef void* id;
typedef id Class;
typedef id SEL;

extern Class objc_getClass(const char* name);
extern SEL sel_registerName(const char* name);
extern void objc_msgSend(void);
extern void* objc_autoreleasePoolPush(void);
extern void objc_autoreleasePoolPop(void* pool);

#define cls(name) objc_getClass(name)
#define sel(name) sel_registerName(name)
#define msg_id0 ((id (*)(id, SEL))objc_msgSend)
#define msg_void ((void (*)(id, SEL))objc_msgSend)
#define msg_void_id ((void (*)(id, SEL, id))objc_msgSend)
#define msg_integer ((long (*)(id, SEL))objc_msgSend)
#define msg_cls_str ((id (*)(Class, SEL, const char*))objc_msgSend)

static id ns_string(const char* string) {
    return msg_cls_str(cls("NSString"), sel("stringWithUTF8String:"), string);
}

// MARK: Main
int main(void) {
    void* pool = objc_autoreleasePoolPush();
    id alert = msg_id0(cls("NSAlert"), sel("new"));
    msg_void_id(alert, sel("setMessageText:"), ns_string("Hello Cocoa from C!"));
    (void)msg_integer(alert, sel("runModal"));
    msg_void(alert, sel("release"));
    objc_autoreleasePoolPop(pool);
    return EXIT_SUCCESS;
}
