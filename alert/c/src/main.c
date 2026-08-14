#include <stdlib.h>

// MARK: Objective-C runtime headers
typedef void* id;
typedef id Class;
typedef id SEL;

extern Class objc_getClass(const char* name);
extern SEL sel_registerName(const char* name);
extern void* objc_msgSend(id self, SEL selector, ...);
extern void* objc_autoreleasePoolPush(void);
extern void objc_autoreleasePoolPop(void* pool);

#define cls(name) objc_getClass(name)
#define sel(name) sel_registerName(name)
#define msg ((id (*)(id, SEL))objc_msgSend)
#define msg_id ((id (*)(id, SEL, id))objc_msgSend)
#define msg_cls_str ((id (*)(Class, SEL, const char*))objc_msgSend)

static id ns_string(const char* string) {
    return msg_cls_str(cls("NSString"), sel("stringWithUTF8String:"), string);
}

// MARK: Main
int main(void) {
    void* pool = objc_autoreleasePoolPush();
    id alert = msg(cls("NSAlert"), sel("new"));
    msg_id(alert, sel("setMessageText:"), ns_string("Hello Cocoa from C!"));
    msg(alert, sel("runModal"));
    msg(alert, sel("release"));
    objc_autoreleasePoolPop(pool);
    return EXIT_SUCCESS;
}
