#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "shader_types.h"

// MARK: Objective-C runtime headers
typedef void* id;
typedef id Class;
typedef id SEL;
typedef id (*IMP)(id self, SEL selector, ...);
typedef void* Ivar;
typedef long NSInteger;
typedef unsigned long NSUInteger;

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
extern Class objc_allocateClassPair(Class superclass, const char* name, size_t extra_bytes);
extern BOOL class_addIvar(Class cls, const char* name, size_t size, uint8_t alignment, const char* types);
extern BOOL class_addMethod(Class cls, SEL name, IMP implementation, const char* types);
extern void objc_registerClassPair(Class cls);
extern SEL sel_registerName(const char* name);
extern void objc_msgSend(void);
#ifndef __arm64__
extern void objc_msgSend_stret(void);
#endif
extern Ivar object_setInstanceVariable(id object, const char* name, void* value);
extern Ivar object_getInstanceVariable(id object, const char* name, void** out_value);
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
#define msg_void_bool ((void (*)(id, SEL, BOOL))objc_msgSend)
#define msg_void_integer ((void (*)(id, SEL, NSInteger))objc_msgSend)
#define msg_void_uint ((void (*)(id, SEL, NSUInteger))objc_msgSend)
#define msg_void_size ((void (*)(id, SEL, NSSize))objc_msgSend)
#define msg_void_rect_bool ((void (*)(id, SEL, NSRect, BOOL))objc_msgSend)
#define msg_void_clear_color ((void (*)(id, SEL, MTLClearColor))objc_msgSend)
#define msg_void_ptr_uint_uint ((void (*)(id, SEL, const void*, NSUInteger, NSUInteger))objc_msgSend)
#define msg_void_uint_uint_uint ((void (*)(id, SEL, NSUInteger, NSUInteger, NSUInteger))objc_msgSend)
#define msg_bool_integer ((BOOL (*)(id, SEL, NSInteger))objc_msgSend)
#define msg_id_sel_id ((id (*)(id, SEL, id, SEL, id))objc_msgSend)
#define msg_id_id ((id (*)(id, SEL, id))objc_msgSend)
#define msg_id_uint ((id (*)(id, SEL, NSUInteger))objc_msgSend)
#define msg_id_id_id_ptr ((id (*)(id, SEL, id, id*))objc_msgSend)
#define msg_id_rect_id ((id (*)(id, SEL, NSRect, id))objc_msgSend)
#define msg_id_rect_uint_uint_bool ((id (*)(id, SEL, NSRect, NSUInteger, NSUInteger, BOOL))objc_msgSend)
#define msg_cls ((id (*)(Class, SEL))objc_msgSend)
#define msg_cls_id ((id (*)(Class, SEL, id))objc_msgSend)
#define msg_ret_uint ((NSUInteger (*)(id, SEL))objc_msgSend)
#define msg_ret_cstr ((const char* (*)(id, SEL))objc_msgSend)
#define msg_super_void ((void (*)(struct objc_super*, SEL))objc_msgSendSuper)

#ifdef __arm64__
#define msg_ret_rect ((NSRect (*)(id, SEL))objc_msgSend)
#else
#define msg_ret_rect(object, selector)                                               \
    ({                                                                               \
        NSRect result;                                                               \
        ((void (*)(NSRect*, id, SEL))objc_msgSend_stret)(&result, object, selector); \
        result;                                                                      \
    })
#endif

// MARK: CoreFoundation headers
typedef const void* CFStringRef;

#define CFSTR(c_string) ((CFStringRef)__builtin___CFStringMakeConstantString("" c_string ""))

// MARK: libdispatch headers
typedef void* dispatch_data_t;
typedef void* dispatch_queue_t;
typedef void (*dispatch_function_t)(void* context);

extern dispatch_data_t dispatch_data_create(const void* buffer, size_t size, dispatch_queue_t queue,
                                            dispatch_function_t destructor);
extern void dispatch_release(void* object);

// MARK: Cocoa and Metal headers
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

typedef struct MTLClearColor {
    double red;
    double green;
    double blue;
    double alpha;
} MTLClearColor;

#define NSApplicationActivationPolicyRegular 0

#define NSWindowStyleMaskTitled 1
#define NSWindowStyleMaskClosable 2
#define NSWindowStyleMaskMiniaturizable 4
#define NSWindowStyleMaskResizable 8
#define NSBackingStoreBuffered 2
#define NSViewWidthSizable 2
#define NSViewHeightSizable 16

#define MTLPixelFormatBGRA8Unorm 80
#define MTLPrimitiveTypeTriangle 3
#define MTLGPUFamilyMetal3 5001
#define MTLGPUFamilyMetal4 5002

static const unsigned char embedded_metallib[] = {
#embed "default.metallib"
};

static const Vertex vertices[] = {
    {.position = {0.0f, 0.75f}, .color = {1.0f, 0.1f, 0.1f, 1.0f}},
    {.position = {-0.7f, -0.6f}, .color = {0.1f, 1.0f, 0.2f, 1.0f}},
    {.position = {0.7f, -0.6f}, .color = {0.1f, 0.3f, 1.0f, 1.0f}},
};

static void print_error(const char* message, id error) {
    if (error == NULL) {
        fprintf(stderr, "%s\n", message);
        return;
    }
    id description = msg_id0(error, sel("localizedDescription"));
    fprintf(stderr, "%s: %s\n", message, msg_ret_cstr(description, sel("UTF8String")));
}

extern id NSApp;
extern id NSAppearanceNameDarkAqua;
extern id MTLCreateSystemDefaultDevice(void);

// MARK: Renderer
bool renderer_configure(id self, id view) {
    id device = msg_id0(view, sel("device"));
    if (device == NULL) {
        print_error("Metal view has no device", NULL);
        return false;
    }

    id library = NULL;
    id pipeline_descriptor = NULL;
    id vertex_function = NULL;
    id fragment_function = NULL;
    id pipeline_state = NULL;
    id command_queue = NULL;
    dispatch_data_t library_data = NULL;
    bool success = false;

    library_data = dispatch_data_create(embedded_metallib, sizeof(embedded_metallib), NULL, NULL);
    if (library_data == NULL) {
        print_error("Could not create Metal library data", NULL);
        goto cleanup;
    }

    id error = NULL;
    library = msg_id_id_id_ptr(device, sel("newLibraryWithData:error:"), (id)library_data, &error);
    if (library == NULL) {
        print_error("Could not load Metal library", error);
        goto cleanup;
    }

    pipeline_descriptor = msg_cls(cls("MTLRenderPipelineDescriptor"), sel("new"));
    vertex_function = msg_id_id(library, sel("newFunctionWithName:"), (id)CFSTR("vertex_main"));
    fragment_function = msg_id_id(library, sel("newFunctionWithName:"), (id)CFSTR("fragment_main"));
    if (vertex_function == NULL || fragment_function == NULL) {
        print_error("Could not load Metal shader functions", NULL);
        goto cleanup;
    }
    msg_void_id(pipeline_descriptor, sel("setVertexFunction:"), vertex_function);
    msg_void_id(pipeline_descriptor, sel("setFragmentFunction:"), fragment_function);

    id color_attachments = msg_id0(pipeline_descriptor, sel("colorAttachments"));
    id color_attachment = msg_id_uint(color_attachments, sel("objectAtIndexedSubscript:"), 0);
    msg_void_uint(color_attachment, sel("setPixelFormat:"), msg_ret_uint(view, sel("colorPixelFormat")));

    error = NULL;
    pipeline_state =
        msg_id_id_id_ptr(device, sel("newRenderPipelineStateWithDescriptor:error:"), pipeline_descriptor, &error);
    if (pipeline_state == NULL) {
        print_error("Could not create Metal pipeline", error);
        goto cleanup;
    }

    command_queue = msg_id0(device, sel("newCommandQueue"));
    if (command_queue == NULL) {
        print_error("Could not create Metal command queue", NULL);
        goto cleanup;
    }

    object_setInstanceVariable(self, "_pipelineState", pipeline_state);
    object_setInstanceVariable(self, "_commandQueue", command_queue);
    pipeline_state = NULL;
    command_queue = NULL;
    success = true;

cleanup:
    if (library_data != NULL) {
        dispatch_release(library_data);
    }
    if (command_queue != NULL) {
        msg_void(command_queue, sel("release"));
    }
    if (pipeline_state != NULL) {
        msg_void(pipeline_state, sel("release"));
    }
    if (fragment_function != NULL) {
        msg_void(fragment_function, sel("release"));
    }
    if (vertex_function != NULL) {
        msg_void(vertex_function, sel("release"));
    }
    if (pipeline_descriptor != NULL) {
        msg_void(pipeline_descriptor, sel("release"));
    }
    if (library != NULL) {
        msg_void(library, sel("release"));
    }
    return success;
}

void renderer_drawable_size_will_change(id self, SEL cmd, id view, NSSize size) {
    (void)self;
    (void)cmd;
    (void)view;
    (void)size;
}

void renderer_draw(id self, SEL cmd, id view) {
    (void)cmd;
    void* pool = objc_autoreleasePoolPush();

    id render_pass = msg_id0(view, sel("currentRenderPassDescriptor"));
    id drawable = msg_id0(view, sel("currentDrawable"));
    if (render_pass == NULL || drawable == NULL) {
        objc_autoreleasePoolPop(pool);
        return;
    }

    id command_queue = NULL;
    id pipeline_state = NULL;
    object_getInstanceVariable(self, "_commandQueue", (void**)&command_queue);
    object_getInstanceVariable(self, "_pipelineState", (void**)&pipeline_state);

    id command_buffer = msg_id0(command_queue, sel("commandBuffer"));
    msg_void_id(command_buffer, sel("setLabel:"), (id)CFSTR("Rainbow Triangle"));

    id encoder = msg_id_id(command_buffer, sel("renderCommandEncoderWithDescriptor:"), render_pass);
    msg_void_id(encoder, sel("setLabel:"), (id)CFSTR("Triangle Render Pass"));
    msg_void_id(encoder, sel("setRenderPipelineState:"), pipeline_state);
    msg_void_ptr_uint_uint(encoder, sel("setVertexBytes:length:atIndex:"), vertices, sizeof(vertices),
                           BufferIndexVertices);
    msg_void_uint_uint_uint(encoder, sel("drawPrimitives:vertexStart:vertexCount:"), MTLPrimitiveTypeTriangle, 0,
                            sizeof(vertices) / sizeof(vertices[0]));
    msg_void(encoder, sel("endEncoding"));

    msg_void_id(command_buffer, sel("presentDrawable:"), drawable);
    msg_void(command_buffer, sel("commit"));
    objc_autoreleasePoolPop(pool);
}

void renderer_dealloc(id self, SEL cmd) {
    (void)cmd;
    id command_queue = NULL;
    id pipeline_state = NULL;
    object_getInstanceVariable(self, "_commandQueue", (void**)&command_queue);
    object_getInstanceVariable(self, "_pipelineState", (void**)&pipeline_state);
    if (command_queue != NULL) {
        msg_void(command_queue, sel("release"));
    }
    if (pipeline_state != NULL) {
        msg_void(pipeline_state, sel("release"));
    }
    struct objc_super super = {self, cls("NSObject")};
    msg_super_void(&super, sel("dealloc"));
}

// MARK: AppDelegate
void app_delegate_did_finish_launching(id self, SEL cmd, id notification) {
    (void)cmd;
    (void)notification;

    id main_menu = msg_cls(cls("NSMenu"), sel("new"));
    msg_void_id(NSApp, sel("setMainMenu:"), main_menu);
    msg_void(main_menu, sel("release"));

    id app_menu_item = msg_cls(cls("NSMenuItem"), sel("new"));
    msg_void_id(main_menu, sel("addItem:"), app_menu_item);
    msg_void(app_menu_item, sel("release"));

    id app_menu = msg_cls(cls("NSMenu"), sel("new"));
    msg_void_id(app_menu_item, sel("setSubmenu:"), app_menu);
    msg_void(app_menu, sel("release"));

    id quit_item = msg_id_sel_id(msg_cls(cls("NSMenuItem"), sel("alloc")), sel("initWithTitle:action:keyEquivalent:"),
                                 (id)CFSTR("Quit Triangle"), sel("terminate:"), (id)CFSTR("q"));
    msg_void_id(app_menu, sel("addItem:"), quit_item);
    msg_void(quit_item, sel("release"));

    id window =
        msg_id_rect_uint_uint_bool(msg_cls(cls("NSWindow"), sel("alloc")),
                                   sel("initWithContentRect:styleMask:backing:defer:"), (NSRect){0, 0, 1024, 768},
                                   NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                       NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable,
                                   NSBackingStoreBuffered, NO);
    object_setInstanceVariable(self, "_window", window);
    msg_void_bool(window, sel("setReleasedWhenClosed:"), NO);
    msg_void_id(window, sel("setTitle:"), (id)CFSTR("Triangle"));
    msg_void_id(window, sel("setAppearance:"),
                msg_cls_id(cls("NSAppearance"), sel("appearanceNamed:"), NSAppearanceNameDarkAqua));

    id screen = msg_id0(window, sel("screen"));
    if (screen != NULL) {
        NSRect screen_frame = msg_ret_rect(screen, sel("frame"));
        NSRect window_frame = msg_ret_rect(window, sel("frame"));
        double window_x = (screen_frame.width - window_frame.width) / 2;
        double window_y = (screen_frame.height - window_frame.height) / 2;
        msg_void_rect_bool(window, sel("setFrame:display:"),
                           (NSRect){window_x, window_y, window_frame.width, window_frame.height}, YES);
    }
    msg_void_size(window, sel("setMinSize:"), (NSSize){480, 360});

    id device = MTLCreateSystemDefaultDevice();
    if (device == NULL) {
        print_error("Metal is not supported on this Mac", NULL);
        msg_void_id(NSApp, sel("terminate:"), NULL);
        return;
    }
    id device_name = msg_id0(device, sel("name"));
    const char* metal_version = "2 or earlier";
    if (msg_bool_integer(device, sel("supportsFamily:"), MTLGPUFamilyMetal4)) {
        metal_version = "4";
    } else if (msg_bool_integer(device, sel("supportsFamily:"), MTLGPUFamilyMetal3)) {
        metal_version = "3";
    }
    fprintf(stderr, "Metal version: %s, device: %s\n", metal_version, msg_ret_cstr(device_name, sel("UTF8String")));

    id content_view = msg_id0(window, sel("contentView"));
    NSRect bounds = msg_ret_rect(content_view, sel("bounds"));
    id metal_view = msg_id_rect_id(msg_cls(cls("MTKView"), sel("alloc")), sel("initWithFrame:device:"), bounds, device);
    msg_void(device, sel("release"));
    msg_void_uint(metal_view, sel("setAutoresizingMask:"), NSViewWidthSizable | NSViewHeightSizable);
    msg_void_uint(metal_view, sel("setColorPixelFormat:"), MTLPixelFormatBGRA8Unorm);
    msg_void_clear_color(metal_view, sel("setClearColor:"), (MTLClearColor){0.015, 0.02, 0.04, 1.0});
    msg_void_integer(metal_view, sel("setPreferredFramesPerSecond:"), 60);

    id renderer = msg_cls(cls("Renderer"), sel("new"));
    if (!renderer_configure(renderer, metal_view)) {
        msg_void(renderer, sel("release"));
        msg_void(metal_view, sel("release"));
        msg_void_id(NSApp, sel("terminate:"), NULL);
        return;
    }
    object_setInstanceVariable(self, "_renderer", renderer);
    msg_void_id(metal_view, sel("setDelegate:"), renderer);
    msg_void_id(window, sel("setContentView:"), metal_view);
    msg_void(metal_view, sel("release"));

    (void)msg_bool_integer(NSApp, sel("setActivationPolicy:"), NSApplicationActivationPolicyRegular);
    msg_void_bool(NSApp, sel("activateIgnoringOtherApps:"), YES);
    msg_void_id(window, sel("makeKeyAndOrderFront:"), NULL);
}

BOOL app_should_terminate_after_last_window_closed(id self, SEL cmd, id sender) {
    (void)self;
    (void)cmd;
    (void)sender;
    return YES;
}

void app_delegate_dealloc(id self, SEL cmd) {
    (void)cmd;
    id renderer = NULL;
    id window = NULL;
    object_getInstanceVariable(self, "_renderer", (void**)&renderer);
    object_getInstanceVariable(self, "_window", (void**)&window);
    if (renderer != NULL) {
        msg_void(renderer, sel("release"));
    }
    if (window != NULL) {
        msg_void(window, sel("release"));
    }
    struct objc_super super = {self, cls("NSObject")};
    msg_super_void(&super, sel("dealloc"));
}

// MARK: Main
int main(void) {
    void* pool = objc_autoreleasePoolPush();

    Class Renderer = objc_allocateClassPair(cls("NSObject"), "Renderer", 0);
    class_addIvar(Renderer, "_commandQueue", sizeof(id), (uint8_t)__builtin_ctzll(_Alignof(id)), "@");
    class_addIvar(Renderer, "_pipelineState", sizeof(id), (uint8_t)__builtin_ctzll(_Alignof(id)), "@");
    class_addMethod(Renderer, sel("mtkView:drawableSizeWillChange:"), (IMP)renderer_drawable_size_will_change,
                    "v@:@{CGSize=dd}");
    class_addMethod(Renderer, sel("drawInMTKView:"), (IMP)renderer_draw, "v@:@");
    class_addMethod(Renderer, sel("dealloc"), (IMP)renderer_dealloc, "v@:");
    objc_registerClassPair(Renderer);

    Class AppDelegate = objc_allocateClassPair(cls("NSObject"), "AppDelegate", 0);
    class_addIvar(AppDelegate, "_window", sizeof(id), (uint8_t)__builtin_ctzll(_Alignof(id)), "@");
    class_addIvar(AppDelegate, "_renderer", sizeof(id), (uint8_t)__builtin_ctzll(_Alignof(id)), "@");
    class_addMethod(AppDelegate, sel("applicationDidFinishLaunching:"), (IMP)app_delegate_did_finish_launching, "v@:@");
    class_addMethod(AppDelegate, sel("applicationShouldTerminateAfterLastWindowClosed:"),
                    (IMP)app_should_terminate_after_last_window_closed, OBJC_BOOL_ENCODING "@:@");
    class_addMethod(AppDelegate, sel("dealloc"), (IMP)app_delegate_dealloc, "v@:");
    objc_registerClassPair(AppDelegate);

    id app = msg_cls(cls("NSApplication"), sel("sharedApplication"));
    id delegate = msg_cls(AppDelegate, sel("new"));
    msg_void_id(app, sel("setDelegate:"), delegate);
    msg_void(app, sel("run"));
    msg_void(delegate, sel("release"));
    objc_autoreleasePoolPop(pool);
    return EXIT_SUCCESS;
}
