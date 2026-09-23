#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>
#import <OpenGL/gl3.h>
#import <QuartzCore/QuartzCore.h>

#import "world.h"

enum { EscapeKeyCode = 53 };

static const vector_float3 skyColor = {0.18f, 0.33f, 0.62f};
// Both voxel passes draw this quad once for each exposed face.
static const GLushort quadIndices[] = {0, 1, 2, 2, 3, 0};

// Embed GLSL in the executable so the app needs no shader resource files.
static const GLchar skyVertexSource[] = {
#embed "shaders/sky.vert"
    , 0};
static const GLchar skyFragmentSource[] = {
#embed "shaders/sky.frag"
    , 0};
static const GLchar voxelVertexSource[] = {
#embed "shaders/voxel.vert"
    , 0};
static const GLchar voxelFragmentSource[] = {
#embed "shaders/voxel.frag"
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
    GLint length = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &length);
    NSMutableData* log = [NSMutableData dataWithLength:(NSUInteger)MAX(length, 1)];
    glGetShaderInfoLog(shader, length, NULL, log.mutableBytes);
    NSLog(@"Could not compile OpenGL shader: %s", (const char*)log.bytes);
    glDeleteShader(shader);
    return 0;
}

static GLuint create_program(const GLchar* vertexSource, const GLchar* fragmentSource) {
    GLuint vertex = compile_shader(GL_VERTEX_SHADER, vertexSource);
    if (vertex == 0) {
        return 0;
    }
    GLuint fragment = compile_shader(GL_FRAGMENT_SHADER, fragmentSource);
    if (fragment == 0) {
        glDeleteShader(vertex);
        return 0;
    }
    GLuint program = glCreateProgram();
    glAttachShader(program, vertex);
    glAttachShader(program, fragment);
    glLinkProgram(program);
    glDeleteShader(vertex);
    glDeleteShader(fragment);
    GLint linked = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (linked == GL_TRUE) {
        return program;
    }
    GLint length = 0;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &length);
    NSMutableData* log = [NSMutableData dataWithLength:(NSUInteger)MAX(length, 1)];
    glGetProgramInfoLog(program, length, NULL, log.mutableBytes);
    NSLog(@"Could not link OpenGL program: %s", (const char*)log.bytes);
    glDeleteProgram(program);
    return 0;
}

static matrix_float4x4 matrix_perspective(float fieldOfView, float aspect, float nearZ, float farZ) {
    // OpenGL clip space uses a depth range of -1 to 1.
    float f = 1.0f / tanf(fieldOfView * 0.5f);
    float range = 1.0f / (nearZ - farZ);
    return (matrix_float4x4){
        .columns[0] = {f / aspect, 0, 0, 0},
        .columns[1] = {0, f, 0, 0},
        .columns[2] = {0, 0, (farZ + nearZ) * range, -1},
        .columns[3] = {0, 0, 2.0f * nearZ * farZ * range, 0},
    };
}

static matrix_float4x4 matrix_look_at(vector_float3 eye, vector_float3 target, vector_float3 up) {
    vector_float3 forward = simd_normalize(target - eye);
    vector_float3 right = simd_normalize(simd_cross(forward, up));
    vector_float3 above = simd_cross(right, forward);
    return (matrix_float4x4){
        .columns[0] = {right.x, above.x, -forward.x, 0},
        .columns[1] = {right.y, above.y, -forward.y, 0},
        .columns[2] = {right.z, above.z, -forward.z, 0},
        .columns[3] = {-simd_dot(right, eye), -simd_dot(above, eye), simd_dot(forward, eye), 1},
    };
}

// Decode the embedded PNGs into one texture array, then build mipmaps once.
static GLuint load_materials(void) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (colorSpace == NULL) {
        return 0;
    }
    GLuint texture = 0;
    size_t textureWidth = 0, textureHeight = 0;
    for (NSUInteger layer = 0; layer < MaterialLayerCount; layer++) {
        NSData* data = [NSData dataWithBytesNoCopy:(void*)materialTextures[layer].bytes
                                            length:materialTextures[layer].length
                                      freeWhenDone:NO];
        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        CGImageRef image = source == NULL ? NULL : CGImageSourceCreateImageAtIndex(source, 0, NULL);
        if (source != NULL) {
            CFRelease(source);
        }
        if (image == NULL) {
            NSLog(@"Could not decode block texture %lu", (unsigned long)layer);
            break;
        }
        size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
        if (layer == 0) {
            textureWidth = width;
            textureHeight = height;
            glGenTextures(1, &texture);
            glBindTexture(GL_TEXTURE_2D_ARRAY, texture);
            glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_SRGB8_ALPHA8, (GLsizei)width, (GLsizei)height, MaterialLayerCount,
                         0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        }
        if (texture == 0 || width != textureWidth || height != textureHeight) {
            NSLog(@"Could not fit block texture %lu into the texture array", (unsigned long)layer);
            CGImageRelease(image);
            break;
        }
        // Core Graphics expands paletted PNGs into the RGBA pixels OpenGL uploads.
        size_t stride = width * 4;
        uint8_t* pixels = calloc(height, stride);
        CGContextRef context = pixels == NULL
                                   ? NULL
                                   : CGBitmapContextCreate(pixels, width, height, 8, stride, colorSpace,
                                                           kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        if (context == NULL) {
            NSLog(@"Could not draw block texture %lu", (unsigned long)layer);
            CGImageRelease(image);
            free(pixels);
            break;
        }
        CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height), image);
        CGContextRelease(context);
        CGImageRelease(image);
        glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, (GLint)layer, (GLsizei)width, (GLsizei)height, 1, GL_RGBA,
                        GL_UNSIGNED_BYTE, pixels);
        free(pixels);
        if (layer == MaterialLayerCount - 1) {
            glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
            glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
            glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_REPEAT);
            glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_REPEAT);
            glBindTexture(GL_TEXTURE_2D_ARRAY, 0);
            CGColorSpaceRelease(colorSpace);
            return texture;
        }
    }
    CGColorSpaceRelease(colorSpace);
    if (texture != 0) {
        glDeleteTextures(1, &texture);
    }
    return 0;
}

@interface StatsView : NSView
@property(nonatomic) double framesPerSecond;
@property(nonatomic) NSUInteger faceCount;
@end

@implementation StatsView

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)isOpaque {
    return NO;
}

- (NSView*)hitTest:(NSPoint)point {
    (void)point;
    return nil;
}

- (void)setFramesPerSecond:(double)framesPerSecond {
    _framesPerSecond = framesPerSecond;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSShadow* shadow = [NSShadow new];
    shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.6];
    shadow.shadowBlurRadius = 3;
    NSDictionary<NSAttributedStringKey, id>* attributes = @{
        NSFontAttributeName : [NSFont monospacedDigitSystemFontOfSize:NSFont.smallSystemFontSize
                                                               weight:NSFontWeightMedium],
        NSForegroundColorAttributeName : NSColor.whiteColor,
        NSShadowAttributeName : shadow,
    };
    NSArray<NSString*>* lines = @[
        [NSString stringWithFormat:@"%.0f FPS", self.framesPerSecond],
        [NSString stringWithFormat:@"%lu faces", (unsigned long)self.faceCount],
    ];
    CGFloat y = 8;
    for (NSString* line in lines) {
        NSSize size = [line sizeWithAttributes:attributes];
        [line drawAtPoint:NSMakePoint(NSWidth(self.bounds) - size.width - 10, y) withAttributes:attributes];
        y += size.height + 2;
    }
}

@end

@interface VoxelView : NSOpenGLView
@property(nonatomic, weak) StatsView* statsView;
- (void)renderFrame;
@end

@implementation VoxelView {
    GLuint _skyProgram;
    GLuint _voxelProgram;
    GLuint _skyArray;
    GLuint _opaqueArray;
    GLuint _waterArray;
    GLuint _indexBuffer;
    GLuint _instanceBuffer;
    GLuint _materials;
    GLint _viewProjectionLocation;
    GLint _cameraPositionLocation;
    GLsizei _opaqueCount;
    GLsizei _translucentCount;
    CFTimeInterval _animationTime;
    CFTimeInterval _lastFrameTime;
    CFTimeInterval _fpsSampleTime;
    NSUInteger _fpsFrameCount;
}

- (instancetype)initWithFrame:(NSRect)frame {
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFAOpenGLProfile,
        NSOpenGLProfileVersion4_1Core,
        NSOpenGLPFAColorSize,
        24,
        NSOpenGLPFAAlphaSize,
        8,
        NSOpenGLPFADepthSize,
        24,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        0,
    };
    NSOpenGLPixelFormat* format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    if (format == nil) {
        NSLog(@"Could not create an OpenGL 4.1 Core pixel format");
        return nil;
    }
    self = [super initWithFrame:frame pixelFormat:format];
    if (self != nil) {
        self.wantsBestResolutionOpenGLSurface = YES;
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}
- (void)keyDown:(NSEvent*)event {
    if (event.keyCode == EscapeKeyCode) {
        [NSApp terminate:nil];
    } else {
        [super keyDown:event];
    }
}

- (void)prepareOpenGL {
    [super prepareOpenGL];
    [self.openGLContext makeCurrentContext];
    NSLog(@"OpenGL version: %s, device: %s", glGetString(GL_VERSION), glGetString(GL_RENDERER));
    GLint swapInterval = 1;
    [self.openGLContext setValues:&swapInterval forParameter:NSOpenGLContextParameterSwapInterval];

    _skyProgram = create_program(skyVertexSource, skyFragmentSource);
    _voxelProgram = create_program(voxelVertexSource, voxelFragmentSource);
    if (_skyProgram == 0 || _voxelProgram == 0) {
        [NSApp terminate:nil];
        return;
    }
    // The sky needs only gl_VertexID; voxel geometry uses an indexed quad.
    glGenVertexArrays(1, &_skyArray);
    glGenVertexArrays(1, &_opaqueArray);
    glGenVertexArrays(1, &_waterArray);
    glBindVertexArray(_opaqueArray);
    glGenBuffers(1, &_indexBuffer);
    glGenBuffers(1, &_instanceBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(quadIndices), quadIndices, GL_STATIC_DRAW);

    // Generate the world once and keep only its exposed faces on the GPU.
    WorldInstances world = world_build();
    if (world.instances == NULL) {
        NSLog(@"Could not allocate the voxel faces");
        [NSApp terminate:nil];
        return;
    }
    _opaqueCount = (GLsizei)world.opaqueCount;
    _translucentCount = (GLsizei)world.translucentCount;
    glBindBuffer(GL_ARRAY_BUFFER, _instanceBuffer);
    glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)(world.opaqueCount + world.translucentCount) * sizeof(VoxelInstance),
                 world.instances, GL_STATIC_DRAW);
    free(world.instances);
    // Two VAOs select the opaque and water ranges of the same instance buffer.
    [self configureInstanceAttributesAtOffset:0];
    glBindVertexArray(_waterArray);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    [self configureInstanceAttributesAtOffset:world.opaqueCount * sizeof(VoxelInstance)];
    glBindVertexArray(0);
    self.statsView.faceCount = world.opaqueCount + world.translucentCount;
    NSLog(@"Visible faces: %lu opaque, %lu water", (unsigned long)world.opaqueCount,
          (unsigned long)world.translucentCount);

    _materials = load_materials();
    if (_materials == 0) {
        [NSApp terminate:nil];
        return;
    }
    glUseProgram(_voxelProgram);
    _viewProjectionLocation = glGetUniformLocation(_voxelProgram, "viewProjection");
    _cameraPositionLocation = glGetUniformLocation(_voxelProgram, "cameraPosition");
    glUniform1i(glGetUniformLocation(_voxelProgram, "materials"), 0);
    glUniform3f(glGetUniformLocation(_voxelProgram, "skyColor"), skyColor.x, skyColor.y, skyColor.z);
    glUniform3f(glGetUniformLocation(_voxelProgram, "sunDirection"), 0.473f, 0.820f, 0.315f);
    glUniform1f(glGetUniformLocation(_voxelProgram, "ambient"), 0.42f);
    glUniform1f(glGetUniformLocation(_voxelProgram, "fogStart"), 120.0f);
    glUniform1f(glGetUniformLocation(_voxelProgram, "fogEnd"), 300.0f);
    glUniform1f(glGetUniformLocation(_voxelProgram, "translucentAlpha"), 0.60f);
    glUseProgram(_skyProgram);
    glUniform3f(glGetUniformLocation(_skyProgram, "skyColor"), skyColor.x, skyColor.y, skyColor.z);
    glUseProgram(0);
    glEnable(GL_FRAMEBUFFER_SRGB);
    glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
}

- (void)configureInstanceAttributesAtOffset:(size_t)offset {
    glBindBuffer(GL_ARRAY_BUFFER, _instanceBuffer);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    // Integer attributes preserve packed cell coordinates and material indices.
    glVertexAttribIPointer(0, 4, GL_SHORT, sizeof(VoxelInstance),
                           (const void*)(offset + offsetof(VoxelInstance, position)));
    glVertexAttribIPointer(1, 4, GL_UNSIGNED_BYTE, sizeof(VoxelInstance),
                           (const void*)(offset + offsetof(VoxelInstance, face)));
    glVertexAttribDivisor(0, 1);
    glVertexAttribDivisor(1, 1);
}

- (void)reshape {
    [super reshape];
    [self.openGLContext makeCurrentContext];
    NSRect bounds = [self convertRectToBacking:self.bounds];
    glViewport(0, 0, (GLsizei)NSWidth(bounds), (GLsizei)NSHeight(bounds));
}

- (void)renderFrame {
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    if (_voxelProgram == 0) {
        return;
    }
    [self.openGLContext makeCurrentContext];
    NSRect bounds = [self convertRectToBacking:self.bounds];
    if (NSWidth(bounds) <= 0 || NSHeight(bounds) <= 0) {
        return;
    }
    CFTimeInterval timestamp = CACurrentMediaTime();
    CFTimeInterval frameTime = timestamp - _lastFrameTime;
    _lastFrameTime = timestamp;
    // Ignore long gaps while the window is hidden or the app is inactive.
    if (frameTime > 0 && frameTime < 0.25) {
        _animationTime += frameTime;
        _fpsFrameCount++;
    } else {
        _fpsSampleTime = timestamp;
        _fpsFrameCount = 0;
    }
    CFTimeInterval fpsInterval = timestamp - _fpsSampleTime;
    if (fpsInterval >= 1.0) {
        self.statsView.framesPerSecond = (double)_fpsFrameCount / fpsInterval;
        _fpsFrameCount = 0;
        _fpsSampleTime = timestamp;
    }

    // Orbit the camera around the center of the diorama.
    float angle = (float)_animationTime * 0.16f;
    vector_float3 target = {WorldSize * 0.5f, WorldSize * 0.34f, WorldSize * 0.5f};
    vector_float3 eye = {target.x + sinf(angle) * 88.0f, target.y + 58.0f, target.z + cosf(angle) * 88.0f};
    matrix_float4x4 view = matrix_look_at(eye, target, (vector_float3){0, 1, 0});
    matrix_float4x4 projection =
        matrix_perspective(50.0f * (float)M_PI / 180.0f, (float)(NSWidth(bounds) / NSHeight(bounds)), 1.0f, 500.0f);
    matrix_float4x4 viewProjection = simd_mul(projection, view);

    // Draw the sky without depth testing, then depth test the solid terrain.
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glUseProgram(_skyProgram);
    glBindVertexArray(_skyArray);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glUseProgram(_voxelProgram);
    glUniformMatrix4fv(_viewProjectionLocation, 1, GL_FALSE, (const GLfloat*)&viewProjection);
    glUniform3f(_cameraPositionLocation, eye.x, eye.y, eye.z);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D_ARRAY, _materials);
    glBindVertexArray(_opaqueArray);
    glDrawElementsInstanced(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, 0, _opaqueCount);
    // Blend water after opaque faces and keep its depth writes disabled.
    if (_translucentCount > 0) {
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDepthMask(GL_FALSE);
        glBindVertexArray(_waterArray);
        glDrawElementsInstanced(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, 0, _translucentCount);
        glDepthMask(GL_TRUE);
        glDisable(GL_BLEND);
    }
    glBindVertexArray(0);
    [self.openGLContext flushBuffer];
}

- (void)dealloc {
    [self.openGLContext makeCurrentContext];
    if (_materials != 0)
        glDeleteTextures(1, &_materials);
    if (_instanceBuffer != 0)
        glDeleteBuffers(1, &_instanceBuffer);
    if (_indexBuffer != 0)
        glDeleteBuffers(1, &_indexBuffer);
    if (_waterArray != 0)
        glDeleteVertexArrays(1, &_waterArray);
    if (_opaqueArray != 0)
        glDeleteVertexArrays(1, &_opaqueArray);
    if (_skyArray != 0)
        glDeleteVertexArrays(1, &_skyArray);
    if (_voxelProgram != 0)
        glDeleteProgram(_voxelProgram);
    if (_skyProgram != 0)
        glDeleteProgram(_skyProgram);
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSWindow* window;
@property(nonatomic, strong) VoxelView* voxelView;
@property(nonatomic, strong) id displayLink;
- (void)updatePausedState;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    (void)notification;
    NSMenu* mainMenu = [NSMenu new];
    NSApp.mainMenu = mainMenu;
    NSMenuItem* appItem = [NSMenuItem new];
    [mainMenu addItem:appItem];
    NSMenu* appMenu = [NSMenu new];
    appItem.submenu = appMenu;
    [appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit Blocks" action:@selector(terminate:) keyEquivalent:@"q"]];

    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1024, 768)
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                        NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.releasedWhenClosed = NO;
    self.window.title = @"Blocks";
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.window.delegate = self;
    CGFloat windowX = (NSWidth(self.window.screen.frame) - NSWidth(self.window.frame)) / 2;
    CGFloat windowY = (NSHeight(self.window.screen.frame) - NSHeight(self.window.frame)) / 2;
    [self.window setFrame:NSMakeRect(windowX, windowY, NSWidth(self.window.frame), NSHeight(self.window.frame))
                  display:YES];
    self.window.minSize = NSMakeSize(480, 360);

    NSView* content = [[NSView alloc] initWithFrame:self.window.contentView.bounds];
    content.wantsLayer = YES;
    self.voxelView = [[VoxelView alloc] initWithFrame:content.bounds];
    if (self.voxelView == nil) {
        [NSApp terminate:nil];
        return;
    }
    self.voxelView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [content addSubview:self.voxelView];
    StatsView* stats = [[StatsView alloc]
        initWithFrame:NSMakeRect(NSWidth(content.bounds) - 140, NSHeight(content.bounds) - 46, 140, 46)];
    stats.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    [content addSubview:stats];
    self.voxelView.statsView = stats;
    self.window.contentView = content;

    // The display link follows the screen refresh rate; older macOS uses a timer.
    if (@available(macOS 14.0, *)) {
        CADisplayLink* link = [self.voxelView displayLinkWithTarget:self.voxelView selector:@selector(renderFrame)];
        self.displayLink = link;
        [link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    } else {
        self.displayLink = [NSTimer timerWithTimeInterval:1.0 / 60.0
                                                   target:self.voxelView
                                                 selector:@selector(renderFrame)
                                                 userInfo:nil
                                                  repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:self.displayLink forMode:NSRunLoopCommonModes];
    }
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.voxelView];
    [self updatePausedState];
}

- (void)windowDidChangeOcclusionState:(NSNotification*)notification {
    (void)notification;
    [self updatePausedState];
}

- (void)applicationDidBecomeActive:(NSNotification*)notification {
    (void)notification;
    [self updatePausedState];
}

- (void)applicationDidResignActive:(NSNotification*)notification {
    (void)notification;
    [self updatePausedState];
}

- (void)updatePausedState {
    BOOL paused = !NSApp.active || (self.window.occlusionState & NSWindowOcclusionStateVisible) == 0;
    if (@available(macOS 14.0, *)) {
        ((CADisplayLink*)self.displayLink).paused = paused;
    } else {
        NSTimer* timer = self.displayLink;
        timer.fireDate = paused ? NSDate.distantFuture : NSDate.date;
    }
}

- (void)applicationWillTerminate:(NSNotification*)notification {
    (void)notification;
    [self.displayLink invalidate];
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
