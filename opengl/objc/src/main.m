#import <Cocoa/Cocoa.h>
#import <OpenGL/gl3.h>

typedef struct {
    GLfloat position[2];
    GLfloat color[4];
} Vertex;

static const Vertex vertices[] = {
    {.position = {0.0f, 0.75f}, .color = {1.0f, 0.1f, 0.1f, 1.0f}},
    {.position = {-0.7f, -0.6f}, .color = {0.1f, 1.0f, 0.2f, 1.0f}},
    {.position = {0.7f, -0.6f}, .color = {0.1f, 0.3f, 1.0f, 1.0f}},
};

static const GLchar vertexShaderSource[] = {
#embed "Shaders.vert"
    , 0};

static const GLchar fragmentShaderSource[] = {
#embed "Shaders.frag"
    , 0};

static GLuint compileShader(GLenum type, const GLchar* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint compiled = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (compiled == GL_TRUE) {
        return shader;
    }

    GLint logLength = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    NSMutableData* logData = [NSMutableData dataWithLength:(NSUInteger)MAX(logLength, 1)];
    glGetShaderInfoLog(shader, logLength, NULL, logData.mutableBytes);
    NSLog(@"Could not compile OpenGL shader: %s", (const char*)logData.bytes);
    glDeleteShader(shader);
    return 0;
}

static GLuint createProgram(void) {
    GLuint vertexShader = compileShader(GL_VERTEX_SHADER, vertexShaderSource);
    if (vertexShader == 0) {
        return 0;
    }

    GLuint fragmentShader = compileShader(GL_FRAGMENT_SHADER, fragmentShaderSource);
    if (fragmentShader == 0) {
        glDeleteShader(vertexShader);
        return 0;
    }

    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    GLint linked = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (linked == GL_TRUE) {
        return program;
    }

    GLint logLength = 0;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    NSMutableData* logData = [NSMutableData dataWithLength:(NSUInteger)MAX(logLength, 1)];
    glGetProgramInfoLog(program, logLength, NULL, logData.mutableBytes);
    NSLog(@"Could not link OpenGL program: %s", (const char*)logData.bytes);
    glDeleteProgram(program);
    return 0;
}

@interface RendererView : NSOpenGLView
@end

@implementation RendererView {
    GLuint _program;
    GLuint _vertexArray;
    GLuint _vertexBuffer;
}

- (instancetype)initWithFrame:(NSRect)frame {
    NSOpenGLPixelFormatAttribute attributes[] = {
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
    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    if (pixelFormat == nil) {
        NSLog(@"Could not create an OpenGL 4.1 Core pixel format");
        return nil;
    }

    self = [super initWithFrame:frame pixelFormat:pixelFormat];
    if (self == nil) {
        return nil;
    }
    self.wantsBestResolutionOpenGLSurface = YES;
    return self;
}

- (void)prepareOpenGL {
    [super prepareOpenGL];
    [self.openGLContext makeCurrentContext];

    NSLog(@"OpenGL version: %s, device: %s", glGetString(GL_VERSION), glGetString(GL_RENDERER));

    GLint swapInterval = 1;
    [self.openGLContext setValues:&swapInterval forParameter:NSOpenGLContextParameterSwapInterval];

    _program = createProgram();
    if (_program == 0) {
        [NSApp terminate:nil];
        return;
    }

    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);

    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const void*)offsetof(Vertex, position));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const void*)offsetof(Vertex, color));

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    glClearColor(0.015f, 0.02f, 0.04f, 1.0f);
}

- (void)reshape {
    [super reshape];
    [self.openGLContext makeCurrentContext];
    NSRect backingBounds = [self convertRectToBacking:self.bounds];
    glViewport(0, 0, (GLsizei)NSWidth(backingBounds), (GLsizei)NSHeight(backingBounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [self.openGLContext makeCurrentContext];

    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(_program);
    glBindVertexArray(_vertexArray);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);
    glUseProgram(0);

    [self.openGLContext flushBuffer];
}

- (void)dealloc {
    [self.openGLContext makeCurrentContext];
    if (_vertexBuffer != 0) {
        glDeleteBuffers(1, &_vertexBuffer);
    }
    if (_vertexArray != 0) {
        glDeleteVertexArrays(1, &_vertexArray);
    }
    if (_program != 0) {
        glDeleteProgram(_program);
    }
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow* window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    (void)notification;

    NSMenu* mainMenu = [NSMenu new];
    NSApp.mainMenu = mainMenu;

    NSMenuItem* appMenuItem = [NSMenuItem new];
    [mainMenu addItem:appMenuItem];

    NSMenu* appMenu = [NSMenu new];
    appMenuItem.submenu = appMenu;
    [appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit Triangle"
                                                action:@selector(terminate:)
                                         keyEquivalent:@"q"]];

    NSRect frame = NSMakeRect(0, 0, 900, 650);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                        NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"OpenGL Triangle";
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    CGFloat windowX = (NSWidth(self.window.screen.frame) - NSWidth(self.window.frame)) / 2;
    CGFloat windowY = (NSHeight(self.window.screen.frame) - NSHeight(self.window.frame)) / 2;
    [self.window setFrame:NSMakeRect(windowX, windowY, NSWidth(self.window.frame), NSHeight(self.window.frame))
                  display:YES];
    self.window.minSize = NSMakeSize(480, 360);

    RendererView* rendererView = [[RendererView alloc] initWithFrame:self.window.contentView.bounds];
    if (rendererView == nil) {
        [NSApp terminate:nil];
        return;
    }
    rendererView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.window.contentView = rendererView;

    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
    (void)sender;
    return YES;
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication* app = NSApplication.sharedApplication;
        AppDelegate* delegate = [AppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return EXIT_SUCCESS;
}
