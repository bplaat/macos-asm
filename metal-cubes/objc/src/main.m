#import <Cocoa/Cocoa.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <MetalKit/MTKTextureLoader.h>
#import <QuartzCore/QuartzCore.h>

#import "ShaderTypes.h"

enum { InstanceCount = 1000 };

static const unsigned char embeddedMetallib[] = {
#embed "default.metallib"
};

static const unsigned char embeddedTexture[] = {
#embed "crate.jpg"
};

static const Vertex vertices[] = {
    // Front
    {{-1, -1, 1, 1}, {0, 1}, {0, 0}},
    {{1, -1, 1, 1}, {1, 1}, {0, 0}},
    {{1, 1, 1, 1}, {1, 0}, {0, 0}},
    {{-1, 1, 1, 1}, {0, 0}, {0, 0}},
    // Back
    {{1, -1, -1, 1}, {0, 1}, {0, 0}},
    {{-1, -1, -1, 1}, {1, 1}, {0, 0}},
    {{-1, 1, -1, 1}, {1, 0}, {0, 0}},
    {{1, 1, -1, 1}, {0, 0}, {0, 0}},
    // Right
    {{1, -1, 1, 1}, {0, 1}, {0, 0}},
    {{1, -1, -1, 1}, {1, 1}, {0, 0}},
    {{1, 1, -1, 1}, {1, 0}, {0, 0}},
    {{1, 1, 1, 1}, {0, 0}, {0, 0}},
    // Left
    {{-1, -1, -1, 1}, {0, 1}, {0, 0}},
    {{-1, -1, 1, 1}, {1, 1}, {0, 0}},
    {{-1, 1, 1, 1}, {1, 0}, {0, 0}},
    {{-1, 1, -1, 1}, {0, 0}, {0, 0}},
    // Top
    {{-1, 1, 1, 1}, {0, 1}, {0, 0}},
    {{1, 1, 1, 1}, {1, 1}, {0, 0}},
    {{1, 1, -1, 1}, {1, 0}, {0, 0}},
    {{-1, 1, -1, 1}, {0, 0}, {0, 0}},
    // Bottom
    {{-1, -1, -1, 1}, {0, 1}, {0, 0}},
    {{1, -1, -1, 1}, {1, 1}, {0, 0}},
    {{1, -1, 1, 1}, {1, 0}, {0, 0}},
    {{-1, -1, 1, 1}, {0, 0}, {0, 0}},
};

static const uint16_t indices[] = {
    0,  1,  2,  2,  3,  0,  4,  5,  6,  6,  7,  4,  8,  9,  10, 10, 11, 8,
    12, 13, 14, 14, 15, 12, 16, 17, 18, 18, 19, 16, 20, 21, 22, 22, 23, 20,
};

static matrix_float4x4 matrix_perspective(float verticalFieldOfView, float aspectRatio, float nearZ, float farZ) {
    float f = tanf((float)M_PI * 0.5f - verticalFieldOfView * 0.5f);
    float rangeInverse = 1.0f / (nearZ - farZ);
    return (matrix_float4x4){
        .columns[0] = {f / aspectRatio, 0, 0, 0},
        .columns[1] = {0, f, 0, 0},
        .columns[2] = {0, 0, farZ * rangeInverse, -1},
        .columns[3] = {0, 0, nearZ * farZ * rangeInverse, 0},
    };
}

static uint32_t random_next(uint32_t* state) {
    uint32_t value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return value;
}

static float random_float(uint32_t* state, float minimum, float maximum) {
    float unit = (float)(random_next(state) & 0x00ffffff) / (float)0x01000000;
    return minimum + unit * (maximum - minimum);
}

static vector_float3 random_unit_vector(uint32_t* state) {
    vector_float3 vector;
    float lengthSquared;
    do {
        vector = (vector_float3){
            random_float(state, -1.0f, 1.0f),
            random_float(state, -1.0f, 1.0f),
            random_float(state, -1.0f, 1.0f),
        };
        lengthSquared = simd_length_squared(vector);
    } while (lengthSquared < 0.001f || lengthSquared > 1.0f);
    return vector / sqrtf(lengthSquared);
}

static id<MTLTexture> load_texture(id<MTLDevice> device) {
    MTKTextureLoader* loader = [[MTKTextureLoader alloc] initWithDevice:device];
    NSDictionary<MTKTextureLoaderOption, id>* options = @{
        MTKTextureLoaderOptionGenerateMipmaps : @YES,
        MTKTextureLoaderOptionOrigin : MTKTextureLoaderOriginTopLeft,
        MTKTextureLoaderOptionSRGB : @YES,
        MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate),
        MTKTextureLoaderOptionTextureUsage : @(MTLTextureUsageShaderRead),
    };
    NSError* error = nil;
    NSData* data = [NSData dataWithBytes:embeddedTexture length:sizeof(embeddedTexture)];
    id<MTLTexture> texture = [loader newTextureWithData:data options:options error:&error];
    if (texture == nil) {
        NSLog(@"Could not create Metal texture: %@", error);
    }
    return texture;
}

@interface MetalView : NSView
- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device;
@property(nonatomic, readonly) CAMetalLayer* metalLayer;
- (void)synchronizeWithScreen;
@end

@implementation MetalView

- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }

    self.wantsLayer = YES;
    CAMetalLayer* layer = self.metalLayer;
    layer.device = device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (colorSpace == NULL) {
        NSLog(@"Could not create sRGB color space");
        return nil;
    }
    layer.colorspace = colorSpace;
    CGColorSpaceRelease(colorSpace);
    layer.framebufferOnly = YES;
    layer.opaque = YES;
    return self;
}

- (CALayer*)makeBackingLayer {
    return [CAMetalLayer layer];
}

- (CAMetalLayer*)metalLayer {
    return (CAMetalLayer*)self.layer;
}

- (void)synchronizeWithScreen {
    CGFloat scale = self.window != nil ? self.window.backingScaleFactor : NSScreen.mainScreen.backingScaleFactor;
    if (scale <= 0) {
        scale = 1;
    }
    self.metalLayer.contentsScale = scale;
    NSSize size = self.bounds.size;
    if (size.width > 0 && size.height > 0) {
        self.metalLayer.drawableSize =
            CGSizeMake(MAX(round(size.width * scale), 1.0), MAX(round(size.height * scale), 1.0));
    }
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self synchronizeWithScreen];
}

- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    [self synchronizeWithScreen];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self synchronizeWithScreen];
}

@end

@interface FPSView : NSView
@property(nonatomic) double framesPerSecond;
@end

@implementation FPSView

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
    NSString* text = [NSString stringWithFormat:@"%.0f FPS", self.framesPerSecond];
    NSDictionary<NSAttributedStringKey, id>* attributes = @{
        NSFontAttributeName : [NSFont systemFontOfSize:NSFont.smallSystemFontSize],
        NSForegroundColorAttributeName : NSColor.whiteColor,
    };
    NSSize size = [text sizeWithAttributes:attributes];
    [text drawAtPoint:NSMakePoint(NSWidth(self.bounds) - size.width - 8, 8) withAttributes:attributes];
}

@end

@interface Renderer : NSObject <CAMetalDisplayLinkDelegate>
- (nullable instancetype)initWithView:(MetalView*)view fpsView:(FPSView*)fpsView;
- (void)updateFrameRate;
- (void)setPaused:(BOOL)paused;
- (void)drawLegacyFrameAtTimestamp:(CFTimeInterval)timestamp;
- (void)renderFrameWithDrawable:(id<CAMetalDrawable>)drawable timestamp:(CFTimeInterval)timestamp;
@end

static CVReturn legacy_display_link_callback(CVDisplayLinkRef displayLink, const CVTimeStamp* now,
                                             const CVTimeStamp* outputTime, CVOptionFlags flagsIn,
                                             CVOptionFlags* flagsOut, void* context) {
    (void)displayLink;
    (void)now;
    (void)flagsIn;
    (void)flagsOut;
    CFTimeInterval timestamp = outputTime->hostTime == 0
                                   ? CACurrentMediaTime()
                                   : (CFTimeInterval)outputTime->hostTime / CVGetHostClockFrequency();
    Renderer* renderer = (__bridge Renderer*)context;
    [renderer drawLegacyFrameAtTimestamp:timestamp];
    return kCVReturnSuccess;
}

@implementation Renderer {
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLDepthStencilState> _depthStencilState;
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    id<MTLBuffer> _instanceBuffer;
    id<MTLTexture> _texture;
    id<MTLSamplerState> _sampler;
    id<MTLTexture> _depthTexture;
    id _displayLink;
    CVDisplayLinkRef _legacyDisplayLink;
    CAMetalLayer* _metalLayer;
    __weak MetalView* _view;
    __weak FPSView* _fpsView;
    CFTimeInterval _animationTime;
    CFTimeInterval _lastFrameTime;
    CFTimeInterval _fpsSampleTime;
    NSUInteger _fpsFrameCount;
}

- (nullable instancetype)initWithView:(MetalView*)view fpsView:(FPSView*)fpsView {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _view = view;
    _fpsView = fpsView;
    _metalLayer = view.metalLayer;
    id<MTLDevice> device = _metalLayer.device;
    _commandQueue = [device newCommandQueue];
    if (_commandQueue == nil) {
        NSLog(@"Could not create Metal command queue");
        return nil;
    }

    NSError* error = nil;
    dispatch_data_t libraryData = dispatch_data_create(embeddedMetallib, sizeof(embeddedMetallib),
                                                       dispatch_get_main_queue(), ^{});
    id<MTLLibrary> library = [device newLibraryWithData:libraryData error:&error];
    if (library == nil) {
        NSLog(@"Could not load Metal library: %@", error);
        return nil;
    }

    MTLRenderPipelineDescriptor* pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"vertex_main"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    if (pipelineDescriptor.vertexFunction == nil || pipelineDescriptor.fragmentFunction == nil) {
        NSLog(@"Could not load Metal shader functions");
        return nil;
    }
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.metalLayer.pixelFormat;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    _pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (_pipelineState == nil) {
        NSLog(@"Could not create Metal pipeline: %@", error);
        return nil;
    }

    MTLDepthStencilDescriptor* depthDescriptor = [MTLDepthStencilDescriptor new];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthDescriptor.depthWriteEnabled = YES;
    _depthStencilState = [device newDepthStencilStateWithDescriptor:depthDescriptor];
    _vertexBuffer = [device newBufferWithBytes:vertices length:sizeof(vertices) options:MTLResourceStorageModeShared];
    _indexBuffer = [device newBufferWithBytes:indices length:sizeof(indices) options:MTLResourceStorageModeShared];

    InstanceData instances[InstanceCount];
    uint32_t randomState = 0x6d2b79f5;
    for (NSUInteger index = 0; index < InstanceCount; index += 2) {
        float distance = random_float(&randomState, 3.0f, 24.0f);
        vector_float3 axis = random_unit_vector(&randomState);
        float speed = random_float(&randomState, 0.35f, 1.4f);
        if ((random_next(&randomState) & 1) != 0) {
            speed = -speed;
        }
        float scale = random_float(&randomState, 0.08f, 0.18f);
        vector_float3 position = {
            random_float(&randomState, -0.9f, 0.9f),
            random_float(&randomState, -0.9f, 0.9f),
            -distance,
        };
        vector_float3 touchingAxis = {0, 0, 0};
        touchingAxis[random_next(&randomState) % 3] = scale * sqrtf(3.0f);
        float phase = random_float(&randomState, 0, 2.0f * (float)M_PI);
        vector_float4 positionAndScale = {position.x, position.y, position.z, scale};
        vector_float4 axisAndSpeed = {axis.x, axis.y, axis.z, speed};
        instances[index] = (InstanceData){
            .positionAndScale = positionAndScale,
            .axisAndSpeed = axisAndSpeed,
            .localOffsetAndPhase = {-touchingAxis.x, -touchingAxis.y, -touchingAxis.z, phase},
        };
        instances[index + 1] = (InstanceData){
            .positionAndScale = positionAndScale,
            .axisAndSpeed = axisAndSpeed,
            .localOffsetAndPhase = {touchingAxis.x, touchingAxis.y, touchingAxis.z, phase},
        };
    }
    _instanceBuffer = [device newBufferWithBytes:instances
                                          length:sizeof(instances)
                                         options:MTLResourceStorageModeShared];
    if (_depthStencilState == nil || _vertexBuffer == nil || _indexBuffer == nil || _instanceBuffer == nil) {
        NSLog(@"Could not create Metal render resources");
        return nil;
    }

    _texture = load_texture(device);
    if (_texture == nil) {
        return nil;
    }

    MTLSamplerDescriptor* samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.mipFilter = MTLSamplerMipFilterLinear;
    _sampler = [device newSamplerStateWithDescriptor:samplerDescriptor];
    if (_sampler == nil) {
        NSLog(@"Could not create Metal sampler");
        return nil;
    }
    // Use variable-refresh-aware frame pacing where it is available.
    if (@available(macOS 14.0, *)) {
        CAMetalDisplayLink* displayLink = [[CAMetalDisplayLink alloc] initWithMetalLayer:_metalLayer];
        displayLink.delegate = self;
        displayLink.preferredFrameLatency = 2.0f;
        _displayLink = displayLink;
        [self updateFrameRate];
        [displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    } else {
        // Keep rendering synchronized to the active display.
        CVReturn result = CVDisplayLinkCreateWithActiveCGDisplays(&_legacyDisplayLink);
        if (result != kCVReturnSuccess) {
            NSLog(@"Could not create legacy display link: %d", result);
            return nil;
        }
        result = CVDisplayLinkSetOutputCallback(_legacyDisplayLink, legacy_display_link_callback, (__bridge void*)self);
        if (result != kCVReturnSuccess) {
            NSLog(@"Could not configure legacy display link: %d", result);
            return nil;
        }
        [self updateFrameRate];
        result = CVDisplayLinkStart(_legacyDisplayLink);
        if (result != kCVReturnSuccess) {
            NSLog(@"Could not start legacy display link: %d", result);
            return nil;
        }
    }
    return self;
}

- (void)updateFrameRate {
    if (@available(macOS 14.0, *)) {
        float maximum = (float)MAX(_view.window.screen.maximumFramesPerSecond, 60);
        CAMetalDisplayLink* displayLink = _displayLink;
        displayLink.preferredFrameRateRange = CAFrameRateRangeMake(30.0f, maximum, maximum);
    } else {
        NSNumber* screenNumber = _view.window.screen.deviceDescription[@"NSScreenNumber"];
        if (screenNumber != nil) {
            CVReturn result = CVDisplayLinkSetCurrentCGDisplay(_legacyDisplayLink, screenNumber.unsignedIntValue);
            if (result != kCVReturnSuccess) {
                NSLog(@"Could not update legacy display link: %d", result);
            }
        }
    }
}

- (void)setPaused:(BOOL)paused {
    if (@available(macOS 14.0, *)) {
        CAMetalDisplayLink* displayLink = _displayLink;
        if (displayLink.paused == paused) {
            return;
        }
        displayLink.paused = paused;
        _lastFrameTime = 0;
        _fpsSampleTime = 0;
        _fpsFrameCount = 0;
    } else {
        BOOL running = CVDisplayLinkIsRunning(_legacyDisplayLink);
        if (running == !paused) {
            return;
        }
        CVReturn result = kCVReturnSuccess;
        if (paused && running) {
            result = CVDisplayLinkStop(_legacyDisplayLink);
        }
        if (result == kCVReturnSuccess) {
            _lastFrameTime = 0;
            _fpsSampleTime = 0;
            _fpsFrameCount = 0;
            if (!paused && !running) {
                result = CVDisplayLinkStart(_legacyDisplayLink);
            }
        }
        if (result != kCVReturnSuccess) {
            NSLog(@"Could not change legacy display link state: %d", result);
        }
    }
}

- (void)metalDisplayLink:(CAMetalDisplayLink*)link
             needsUpdate:(CAMetalDisplayLinkUpdate*)update API_AVAILABLE(macos(14.0)) {
    (void)link;
    [self renderFrameWithDrawable:update.drawable timestamp:update.targetPresentationTimestamp];
}

- (void)drawLegacyFrameAtTimestamp:(CFTimeInterval)timestamp {
    @autoreleasepool {
        id<CAMetalDrawable> drawable = [_metalLayer nextDrawable];
        if (drawable != nil) {
            [self renderFrameWithDrawable:drawable timestamp:timestamp];
        }
    }
}

- (void)renderFrameWithDrawable:(id<CAMetalDrawable>)drawable timestamp:(CFTimeInterval)timestamp {
    @autoreleasepool {
        NSUInteger width = drawable.texture.width;
        NSUInteger height = drawable.texture.height;
        if (width == 0 || height == 0) {
            return;
        }

        if (_depthTexture.width != width || _depthTexture.height != height) {
            MTLTextureDescriptor* depthDescriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                                   width:width
                                                                  height:height
                                                               mipmapped:NO];
            depthDescriptor.storageMode = MTLStorageModePrivate;
            depthDescriptor.usage = MTLTextureUsageRenderTarget;
            _depthTexture = [_metalLayer.device newTextureWithDescriptor:depthDescriptor];
            if (_depthTexture == nil) {
                NSLog(@"Could not create Metal depth texture");
                return;
            }
        }

        if (_lastFrameTime != 0) {
            CFTimeInterval frameTime = timestamp - _lastFrameTime;
            // Ignore suspension gaps so animation resumes without jumping.
            if (frameTime > 0 && frameTime < 0.25) {
                _animationTime += frameTime;
            }
        }
        _lastFrameTime = timestamp;
        if (_fpsSampleTime == 0) {
            _fpsSampleTime = timestamp;
        } else {
            _fpsFrameCount++;
        }
        CFTimeInterval fpsInterval = timestamp - _fpsSampleTime;
        if (fpsInterval >= 0.5) {
            double framesPerSecond = (double)_fpsFrameCount / fpsInterval;
            FPSView* fpsView = _fpsView;
            dispatch_async(dispatch_get_main_queue(), ^{ fpsView.framesPerSecond = framesPerSecond; });
            _fpsFrameCount = 0;
            _fpsSampleTime = timestamp;
        }

        MTLRenderPassDescriptor* renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
        renderPass.colorAttachments[0].texture = drawable.texture;
        renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.015, 0.02, 0.04, 1.0);
        renderPass.depthAttachment.texture = _depthTexture;
        renderPass.depthAttachment.loadAction = MTLLoadActionClear;
        renderPass.depthAttachment.storeAction = MTLStoreActionDontCare;
        renderPass.depthAttachment.clearDepth = 1.0;

        float elapsed = (float)_animationTime;
        float aspectRatio = (float)width / (float)height;
        Uniforms uniforms = {
            .projectionMatrix = matrix_perspective(55.0f * (float)M_PI / 180.0f, aspectRatio, 0.1f, 100.0f),
            .time = {elapsed, 0, 0, 0},
        };

        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        commandBuffer.label = @"Textured Cubes Frame";
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
        encoder.label = @"Cubes Render Pass";
        [encoder setRenderPipelineState:_pipelineState];
        [encoder setDepthStencilState:_depthStencilState];
        [encoder setFrontFacingWinding:MTLWindingClockwise];
        [encoder setCullMode:MTLCullModeBack];
        [encoder setVertexBuffer:_vertexBuffer offset:0 atIndex:BufferIndexVertices];
        [encoder setVertexBuffer:_instanceBuffer offset:0 atIndex:BufferIndexInstances];
        [encoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:BufferIndexUniforms];
        [encoder setFragmentTexture:_texture atIndex:TextureIndexColor];
        [encoder setFragmentSamplerState:_sampler atIndex:SamplerIndexColor];
        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                            indexCount:sizeof(indices) / sizeof(indices[0])
                             indexType:MTLIndexTypeUInt16
                           indexBuffer:_indexBuffer
                     indexBufferOffset:0
                         instanceCount:InstanceCount];
        [encoder endEncoding];
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}

- (void)dealloc {
    if (@available(macOS 14.0, *)) {
        [_displayLink invalidate];
    } else {
        if (_legacyDisplayLink != NULL) {
            CVDisplayLinkStop(_legacyDisplayLink);
            CVDisplayLinkRelease(_legacyDisplayLink);
        }
    }
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSWindow* window;
@property(nonatomic, strong) MetalView* metalView;
@property(nonatomic, strong) Renderer* renderer;
- (void)updateRendererPausedState;
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
    [appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit Metal Cubes"
                                                action:@selector(terminate:)
                                         keyEquivalent:@"q"]];

    NSRect frame = NSMakeRect(0, 0, 900, 650);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                        NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Metal Cubes";
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.window.delegate = self;
    CGFloat windowX = (NSWidth(self.window.screen.frame) - NSWidth(self.window.frame)) / 2;
    CGFloat windowY = (NSHeight(self.window.screen.frame) - NSHeight(self.window.frame)) / 2;
    [self.window setFrame:NSMakeRect(windowX, windowY, NSWidth(self.window.frame), NSHeight(self.window.frame))
                  display:YES];
    self.window.minSize = NSMakeSize(480, 360);

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) {
        NSLog(@"Metal is not supported on this Mac");
        [NSApp terminate:nil];
        return;
    }
    NSLog(@"Metal device: %@", device.name);

    NSView* contentView = [[NSView alloc] initWithFrame:self.window.contentView.bounds];
    contentView.wantsLayer = YES;
    self.metalView = [[MetalView alloc] initWithFrame:contentView.bounds device:device];
    self.metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [contentView addSubview:self.metalView];

    FPSView* fpsView = [[FPSView alloc]
        initWithFrame:NSMakeRect(NSWidth(contentView.bounds) - 80, NSHeight(contentView.bounds) - 24, 80, 24)];
    fpsView.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    [contentView addSubview:fpsView];
    self.window.contentView = contentView;
    [self.metalView synchronizeWithScreen];

    self.renderer = [[Renderer alloc] initWithView:self.metalView fpsView:fpsView];
    if (self.renderer == nil) {
        [NSApp terminate:nil];
        return;
    }

    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
    [self updateRendererPausedState];
}

- (void)windowDidChangeScreen:(NSNotification*)notification {
    (void)notification;
    [self.metalView synchronizeWithScreen];
    [self.renderer updateFrameRate];
}

- (void)windowDidChangeOcclusionState:(NSNotification*)notification {
    (void)notification;
    [self updateRendererPausedState];
}

- (void)updateRendererPausedState {
    BOOL visible = (self.window.occlusionState & NSWindowOcclusionStateVisible) != 0;
    [self.renderer setPaused:!visible];
}

- (void)applicationWillTerminate:(NSNotification*)notification {
    (void)notification;
    [self.renderer setPaused:YES];
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
