#include <OpenGL/gl3.h>
#include <stdbool.h>
#include <stddef.h>
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
extern Class objc_allocateClassPair(Class superclass, const char* name, size_t extra_bytes);
extern bool class_addIvar(Class cls, const char* name, size_t size, uint8_t alignment, const char* types);
extern bool class_addMethod(Class cls, SEL name, IMP implementation, const char* types);
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
#define msg_id_ptr ((id (*)(id, SEL, const uint32_t*))objc_msgSend)
#define msg_id_rect_id ((id (*)(id, SEL, NSRect, id))objc_msgSend)
#define msg_id_sel_id ((id (*)(id, SEL, id, SEL, id))objc_msgSend)
#define msg_void ((void (*)(id, SEL))objc_msgSend)
#define msg_void_id ((void (*)(id, SEL, id))objc_msgSend)
#define msg_void_bool ((void (*)(id, SEL, bool))objc_msgSend)
#define msg_void_uint ((void (*)(id, SEL, NSUInteger))objc_msgSend)
#define msg_void_size ((void (*)(id, SEL, NSSize))objc_msgSend)
#define msg_void_rect_bool ((void (*)(id, SEL, NSRect, bool))objc_msgSend)
#define msg_void_ptr_integer ((void (*)(id, SEL, const int32_t*, NSInteger))objc_msgSend)
#define msg_bool_integer ((bool (*)(id, SEL, NSInteger))objc_msgSend)
#define msg_cls ((id (*)(Class, SEL))objc_msgSend)
#define msg_cls_id ((id (*)(Class, SEL, id))objc_msgSend)
#define msg_cls_str ((id (*)(Class, SEL, const char*))objc_msgSend)
#define msg_super_void ((void (*)(struct objc_super*, SEL))objc_msgSendSuper)

#ifdef __arm64__
#define msg_ret_rect ((NSRect (*)(id, SEL))objc_msgSend)
#define msg_rect_rect ((NSRect (*)(id, SEL, NSRect))objc_msgSend)
#else
#define msg_ret_rect(object, selector)                                               \
    ({                                                                               \
        NSRect result;                                                               \
        ((void (*)(NSRect*, id, SEL))objc_msgSend_stret)(&result, object, selector); \
        result;                                                                      \
    })
#define msg_rect_rect(object, selector, rect)                                                      \
    ({                                                                                             \
        NSRect result;                                                                             \
        ((void (*)(NSRect*, id, SEL, NSRect))objc_msgSend_stret)(&result, object, selector, rect); \
        result;                                                                                    \
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
#define NSViewWidthSizable 2
#define NSViewHeightSizable 16

#define NSOpenGLPFADoubleBuffer 5
#define NSOpenGLPFAColorSize 8
#define NSOpenGLPFAAlphaSize 11
#define NSOpenGLPFAAccelerated 73
#define NSOpenGLPFAOpenGLProfile 99
#define NSOpenGLProfileVersion4_1Core 0x4100
#define NSOpenGLContextParameterSwapInterval 222

extern id NSApp;
extern id NSAppearanceNameDarkAqua;

static id ns_string(const char* string) {
    return msg_cls_str(cls("NSString"), sel("stringWithUTF8String:"), string);
}

// MARK: OpenGL renderer
typedef struct Vertex {
    GLfloat position[2];
    GLfloat color[4];
} Vertex;

typedef struct RendererState {
    GLuint program;
    GLuint vertex_array;
    GLuint vertex_buffer;
} RendererState;

static const Vertex vertices[] = {
    {.position = {0.0f, 0.75f}, .color = {1.0f, 0.1f, 0.1f, 1.0f}},
    {.position = {-0.7f, -0.6f}, .color = {0.1f, 1.0f, 0.2f, 1.0f}},
    {.position = {0.7f, -0.6f}, .color = {0.1f, 0.3f, 1.0f, 1.0f}},
};

static const GLchar vertex_shader_source[] = {
#embed "Shaders.vert"
    , 0};

static const GLchar fragment_shader_source[] = {
#embed "Shaders.frag"
    , 0};

static GLuint compile_shader(GLenum type, const GLchar* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint compiled = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (compiled == GL_TRUE) {
        return shader;
    }

    GLint log_length = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &log_length);
    GLsizei buffer_length = log_length > 0 ? log_length : 1;
    GLchar* log = calloc((size_t)buffer_length, sizeof(GLchar));
    glGetShaderInfoLog(shader, buffer_length, NULL, log);
    fprintf(stderr, "Could not compile OpenGL shader: %s\n", log);
    free(log);
    glDeleteShader(shader);
    return 0;
}

static GLuint create_program(void) {
    GLuint vertex_shader = compile_shader(GL_VERTEX_SHADER, vertex_shader_source);
    if (vertex_shader == 0) {
        return 0;
    }

    GLuint fragment_shader = compile_shader(GL_FRAGMENT_SHADER, fragment_shader_source);
    if (fragment_shader == 0) {
        glDeleteShader(vertex_shader);
        return 0;
    }

    GLuint program = glCreateProgram();
    glAttachShader(program, vertex_shader);
    glAttachShader(program, fragment_shader);
    glLinkProgram(program);
    glDeleteShader(vertex_shader);
    glDeleteShader(fragment_shader);

    GLint linked = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (linked == GL_TRUE) {
        return program;
    }

    GLint log_length = 0;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &log_length);
    GLsizei buffer_length = log_length > 0 ? log_length : 1;
    GLchar* log = calloc((size_t)buffer_length, sizeof(GLchar));
    glGetProgramInfoLog(program, buffer_length, NULL, log);
    fprintf(stderr, "Could not link OpenGL program: %s\n", log);
    free(log);
    glDeleteProgram(program);
    return 0;
}

static RendererState* renderer_state(id self) {
    RendererState* state = NULL;
    object_getInstanceVariable(self, "_state", (void**)&state);
    return state;
}

void renderer_prepare_opengl(id self, SEL cmd) {
    (void)cmd;
    struct objc_super super = {self, cls("NSOpenGLView")};
    msg_super_void(&super, sel("prepareOpenGL"));

    id context = msg_id0(self, sel("openGLContext"));
    msg_void(context, sel("makeCurrentContext"));
    fprintf(stderr, "OpenGL version: %s, device: %s\n", (const char*)glGetString(GL_VERSION),
            (const char*)glGetString(GL_RENDERER));

    int32_t swap_interval = 1;
    msg_void_ptr_integer(context, sel("setValues:forParameter:"), &swap_interval, NSOpenGLContextParameterSwapInterval);

    RendererState* state = calloc(1, sizeof(RendererState));
    state->program = create_program();
    if (state->program == 0) {
        free(state);
        msg_void_id(NSApp, sel("terminate:"), NULL);
        return;
    }

    glGenVertexArrays(1, &state->vertex_array);
    glBindVertexArray(state->vertex_array);
    glGenBuffers(1, &state->vertex_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, state->vertex_buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const void*)offsetof(Vertex, position));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const void*)offsetof(Vertex, color));
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    glClearColor(0.015f, 0.02f, 0.04f, 1.0f);

    object_setInstanceVariable(self, "_state", state);
}

void renderer_reshape(id self, SEL cmd) {
    (void)cmd;
    struct objc_super super = {self, cls("NSOpenGLView")};
    msg_super_void(&super, sel("reshape"));

    id context = msg_id0(self, sel("openGLContext"));
    msg_void(context, sel("makeCurrentContext"));
    NSRect bounds = msg_ret_rect(self, sel("bounds"));
    NSRect backing_bounds = msg_rect_rect(self, sel("convertRectToBacking:"), bounds);
    glViewport(0, 0, (GLsizei)backing_bounds.width, (GLsizei)backing_bounds.height);
}

void renderer_draw_rect(id self, SEL cmd, NSRect dirty_rect) {
    (void)cmd;
    (void)dirty_rect;
    id context = msg_id0(self, sel("openGLContext"));
    msg_void(context, sel("makeCurrentContext"));

    RendererState* state = renderer_state(self);
    if (state == NULL) {
        return;
    }
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(state->program);
    glBindVertexArray(state->vertex_array);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);
    glUseProgram(0);
    msg_void(context, sel("flushBuffer"));
}

void renderer_dealloc(id self, SEL cmd) {
    (void)cmd;
    RendererState* state = renderer_state(self);
    if (state != NULL) {
        id context = msg_id0(self, sel("openGLContext"));
        msg_void(context, sel("makeCurrentContext"));
        if (state->vertex_buffer != 0) {
            glDeleteBuffers(1, &state->vertex_buffer);
        }
        if (state->vertex_array != 0) {
            glDeleteVertexArrays(1, &state->vertex_array);
        }
        if (state->program != 0) {
            glDeleteProgram(state->program);
        }
        free(state);
    }
    struct objc_super super = {self, cls("NSOpenGLView")};
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
                                 ns_string("Quit Triangle"), sel("terminate:"), ns_string("q"));
    msg_void_id(app_menu, sel("addItem:"), quit_item);
    msg_void(quit_item, sel("release"));

    id window = ((id (*)(id, SEL, NSRect, NSUInteger, NSUInteger, bool))objc_msgSend)(
        msg_cls(cls("NSWindow"), sel("alloc")), sel("initWithContentRect:styleMask:backing:defer:"),
        (NSRect){0, 0, 900, 650},
        NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable |
            NSWindowStyleMaskResizable,
        NSBackingStoreBuffered, false);
    object_setInstanceVariable(self, "_window", window);
    msg_void_bool(window, sel("setReleasedWhenClosed:"), false);
    msg_void_id(window, sel("setTitle:"), ns_string("OpenGL Triangle"));
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
    msg_void_size(window, sel("setMinSize:"), (NSSize){480, 360});

    uint32_t attributes[] = {
        NSOpenGLPFAOpenGLProfile,
        NSOpenGLProfileVersion4_1Core,
        NSOpenGLPFAColorSize,
        24,
        NSOpenGLPFAAlphaSize,
        8,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        0,
    };
    id pixel_format =
        msg_id_ptr(msg_cls(cls("NSOpenGLPixelFormat"), sel("alloc")), sel("initWithAttributes:"), attributes);
    if (pixel_format == NULL) {
        fprintf(stderr, "Could not create an OpenGL 4.1 Core pixel format\n");
        msg_void_id(NSApp, sel("terminate:"), NULL);
        return;
    }

    id content_view = msg_id0(window, sel("contentView"));
    id renderer = msg_id_rect_id(msg_cls(cls("RendererView"), sel("alloc")), sel("initWithFrame:pixelFormat:"),
                                 msg_ret_rect(content_view, sel("bounds")), pixel_format);
    msg_void(pixel_format, sel("release"));
    if (renderer == NULL) {
        fprintf(stderr, "Could not create the OpenGL renderer view\n");
        msg_void_id(NSApp, sel("terminate:"), NULL);
        return;
    }
    msg_void_bool(renderer, sel("setWantsBestResolutionOpenGLSurface:"), true);
    msg_void_uint(renderer, sel("setAutoresizingMask:"), NSViewWidthSizable | NSViewHeightSizable);
    msg_void_id(window, sel("setContentView:"), renderer);
    msg_void(renderer, sel("release"));

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

    Class RendererView = objc_allocateClassPair(cls("NSOpenGLView"), "RendererView", 0);
    class_addIvar(RendererView, "_state", sizeof(RendererState*), (uint8_t)__builtin_ctzll(_Alignof(RendererState*)),
                  "^v");
    class_addMethod(RendererView, sel("prepareOpenGL"), (IMP)renderer_prepare_opengl, "v@:");
    class_addMethod(RendererView, sel("reshape"), (IMP)renderer_reshape, "v@:");
    class_addMethod(RendererView, sel("drawRect:"), (IMP)renderer_draw_rect, "v@:{NSRect={CGPoint=dd}{CGSize=dd}}");
    class_addMethod(RendererView, sel("dealloc"), (IMP)renderer_dealloc, "v@:");
    objc_registerClassPair(RendererView);

    Class AppDelegate = objc_allocateClassPair(cls("NSObject"), "AppDelegate", 0);
    class_addIvar(AppDelegate, "_window", sizeof(id), (uint8_t)__builtin_ctzll(_Alignof(id)), "@");
    class_addMethod(AppDelegate, sel("applicationDidFinishLaunching:"), (IMP)app_delegate_did_finish_launching, "v@:@");
    class_addMethod(AppDelegate, sel("applicationShouldTerminateAfterLastWindowClosed:"),
                    (IMP)app_should_terminate_after_last_window_closed, "B@:@");
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
