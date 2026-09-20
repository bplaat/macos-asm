#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>

#import "shader_types.h"
#import "world.h"

static const unsigned char embeddedMetallib[] = {
#embed "default.metallib"
};

enum { EscapeKeyCode = 53 };

// The display may drop to this rate to save power when it needs to.
static const float MinimumFramesPerSecond = 30.0f;

static const vector_float3 skyColor = {0.18f, 0.33f, 0.62f};

// The corners of a unit cube, four per face in the order world.h numbers them.
// Each instance draws one face, and its normal shades that face.
static const Vertex vertices[] = {
    // Front
    {{-1, -1, 1, 1}, {0, 0, 1, 0}, {0, 1}, {0, 0}},
    {{1, -1, 1, 1}, {0, 0, 1, 0}, {1, 1}, {0, 0}},
    {{1, 1, 1, 1}, {0, 0, 1, 0}, {1, 0}, {0, 0}},
    {{-1, 1, 1, 1}, {0, 0, 1, 0}, {0, 0}, {0, 0}},
    // Back
    {{1, -1, -1, 1}, {0, 0, -1, 0}, {0, 1}, {0, 0}},
    {{-1, -1, -1, 1}, {0, 0, -1, 0}, {1, 1}, {0, 0}},
    {{-1, 1, -1, 1}, {0, 0, -1, 0}, {1, 0}, {0, 0}},
    {{1, 1, -1, 1}, {0, 0, -1, 0}, {0, 0}, {0, 0}},
    // Right
    {{1, -1, 1, 1}, {1, 0, 0, 0}, {0, 1}, {0, 0}},
    {{1, -1, -1, 1}, {1, 0, 0, 0}, {1, 1}, {0, 0}},
    {{1, 1, -1, 1}, {1, 0, 0, 0}, {1, 0}, {0, 0}},
    {{1, 1, 1, 1}, {1, 0, 0, 0}, {0, 0}, {0, 0}},
    // Left
    {{-1, -1, -1, 1}, {-1, 0, 0, 0}, {0, 1}, {0, 0}},
    {{-1, -1, 1, 1}, {-1, 0, 0, 0}, {1, 1}, {0, 0}},
    {{-1, 1, 1, 1}, {-1, 0, 0, 0}, {1, 0}, {0, 0}},
    {{-1, 1, -1, 1}, {-1, 0, 0, 0}, {0, 0}, {0, 0}},
    // Top
    {{-1, 1, 1, 1}, {0, 1, 0, 0}, {0, 1}, {0, 0}},
    {{1, 1, 1, 1}, {0, 1, 0, 0}, {1, 1}, {0, 0}},
    {{1, 1, -1, 1}, {0, 1, 0, 0}, {1, 0}, {0, 0}},
    {{-1, 1, -1, 1}, {0, 1, 0, 0}, {0, 0}, {0, 0}},
    // Bottom
    {{-1, -1, -1, 1}, {0, -1, 0, 0}, {0, 1}, {0, 0}},
    {{1, -1, -1, 1}, {0, -1, 0, 0}, {1, 1}, {0, 0}},
    {{1, -1, 1, 1}, {0, -1, 0, 0}, {1, 0}, {0, 0}},
    {{-1, -1, 1, 1}, {0, -1, 0, 0}, {0, 0}, {0, 0}},
};

// One quad, drawn once per visible face; the vertex shader picks which four of
// the cube's corners to read.
static const uint16_t indices[] = {0, 1, 2, 2, 3, 0};

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

static CGImageRef create_material_image(NSUInteger layer) CF_RETURNS_RETAINED {
    NSData* data = [NSData dataWithBytesNoCopy:(void*)materialTextures[layer].bytes
                                        length:materialTextures[layer].length
                                  freeWhenDone:NO];
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (source == NULL) {
        return NULL;
    }
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    return image;
}

// Decodes every embedded block texture into a slice of one mipmapped texture
// array, so a single sampler can serve all block materials.
static id<MTLTexture> load_materials(id<MTLDevice> device, id<MTLCommandQueue> commandQueue) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (colorSpace == NULL) {
        NSLog(@"Could not create sRGB color space");
        return nil;
    }

    id<MTLTexture> materials = nil;
    for (NSUInteger layer = 0; layer < MaterialLayerCount; layer++) {
        CGImageRef image = create_material_image(layer);
        if (image == NULL) {
            NSLog(@"Could not decode block texture %lu", (unsigned long)layer);
            break;
        }
        size_t width = CGImageGetWidth(image);
        size_t height = CGImageGetHeight(image);
        if (materials == nil) {
            MTLTextureDescriptor* descriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm_sRGB
                                                                   width:width
                                                                  height:height
                                                               mipmapped:YES];
            descriptor.textureType = MTLTextureType2DArray;
            descriptor.arrayLength = MaterialLayerCount;
            descriptor.storageMode = MTLStorageModeShared;
            descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
            materials = [device newTextureWithDescriptor:descriptor];
        }
        if (materials == nil || width != materials.width || height != materials.height) {
            NSLog(@"Could not fit block texture %lu into the texture array", (unsigned long)layer);
            CGImageRelease(image);
            materials = nil;
            break;
        }

        // Paletted PNGs only arrive as plain pixels after a Core Graphics draw.
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
            materials = nil;
            break;
        }
        CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height), image);
        CGContextRelease(context);
        CGImageRelease(image);
        [materials replaceRegion:MTLRegionMake2D(0, 0, width, height)
                     mipmapLevel:0
                           slice:layer
                       withBytes:pixels
                     bytesPerRow:stride
                   bytesPerImage:stride * height];
        free(pixels);
    }
    CGColorSpaceRelease(colorSpace);
    if (materials == nil) {
        return nil;
    }

    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> encoder = [commandBuffer blitCommandEncoder];
    [encoder generateMipmapsForTexture:materials];
    [encoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    return materials;
}

// MTKView owns the layer, the drawable, the depth buffer, and the frame clock.
@interface VoxelView : MTKView
@end

@implementation VoxelView

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent*)event {
    if (event.keyCode == EscapeKeyCode) {
        [NSApp terminate:nil];
        return;
    }
    [super keyDown:event];
}

@end

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

@interface Renderer : NSObject <MTKViewDelegate>
- (nullable instancetype)initWithView:(MTKView*)view statsView:(StatsView*)statsView;
@end

@implementation Renderer {
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _skyPipelineState;
    id<MTLRenderPipelineState> _opaquePipelineState;
    id<MTLRenderPipelineState> _translucentPipelineState;
    id<MTLDepthStencilState> _skyDepthState;
    id<MTLDepthStencilState> _opaqueDepthState;
    id<MTLDepthStencilState> _translucentDepthState;
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    id<MTLBuffer> _instanceBuffer;
    id<MTLTexture> _materials;
    id<MTLSamplerState> _sampler;
    __weak StatsView* _statsView;
    NSUInteger _opaqueCount;
    NSUInteger _translucentCount;
    CFTimeInterval _animationTime;
    CFTimeInterval _lastFrameTime;
    CFTimeInterval _fpsSampleTime;
    NSUInteger _fpsFrameCount;
}

- (nullable instancetype)initWithView:(MTKView*)view statsView:(StatsView*)statsView {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _statsView = statsView;
    id<MTLDevice> device = view.device;
    _commandQueue = [device newCommandQueue];
    if (_commandQueue == nil) {
        NSLog(@"Could not create Metal command queue");
        return nil;
    }

    NSError* error = nil;
    dispatch_data_t libraryData =
        dispatch_data_create(embeddedMetallib, sizeof(embeddedMetallib), dispatch_get_main_queue(), ^{});
    id<MTLLibrary> library = [device newLibraryWithData:libraryData error:&error];
    if (library == nil) {
        NSLog(@"Could not load Metal library: %@", error);
        return nil;
    }

    MTLRenderPipelineDescriptor* skyDescriptor = [MTLRenderPipelineDescriptor new];
    skyDescriptor.label = @"Sky";
    skyDescriptor.vertexFunction = [library newFunctionWithName:@"sky_vertex"];
    skyDescriptor.fragmentFunction = [library newFunctionWithName:@"sky_fragment"];
    skyDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    skyDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    _skyPipelineState = [device newRenderPipelineStateWithDescriptor:skyDescriptor error:&error];

    MTLRenderPipelineDescriptor* voxelDescriptor = [MTLRenderPipelineDescriptor new];
    voxelDescriptor.label = @"Opaque voxels";
    voxelDescriptor.vertexFunction = [library newFunctionWithName:@"voxel_vertex"];
    voxelDescriptor.fragmentFunction = [library newFunctionWithName:@"voxel_fragment"];
    voxelDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    voxelDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    _opaquePipelineState = [device newRenderPipelineStateWithDescriptor:voxelDescriptor error:&error];

    // The water surface reuses the voxel shaders but blends over the terrain.
    voxelDescriptor.label = @"Translucent voxels";
    MTLRenderPipelineColorAttachmentDescriptor* attachment = voxelDescriptor.colorAttachments[0];
    attachment.blendingEnabled = YES;
    attachment.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    attachment.sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    attachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    attachment.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    _translucentPipelineState = [device newRenderPipelineStateWithDescriptor:voxelDescriptor error:&error];
    if (_skyPipelineState == nil || _opaquePipelineState == nil || _translucentPipelineState == nil) {
        NSLog(@"Could not create Metal pipelines: %@", error);
        return nil;
    }

    MTLDepthStencilDescriptor* depthDescriptor = [MTLDepthStencilDescriptor new];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionAlways;
    depthDescriptor.depthWriteEnabled = NO;
    _skyDepthState = [device newDepthStencilStateWithDescriptor:depthDescriptor];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    _translucentDepthState = [device newDepthStencilStateWithDescriptor:depthDescriptor];
    depthDescriptor.depthWriteEnabled = YES;
    _opaqueDepthState = [device newDepthStencilStateWithDescriptor:depthDescriptor];

    _vertexBuffer = [device newBufferWithBytes:vertices length:sizeof(vertices) options:MTLResourceStorageModeShared];
    _indexBuffer = [device newBufferWithBytes:indices length:sizeof(indices) options:MTLResourceStorageModeShared];

    WorldInstances world = world_build();
    if (world.instances == NULL) {
        NSLog(@"Could not allocate the voxel faces");
        return nil;
    }
    _opaqueCount = world.opaqueCount;
    _translucentCount = world.translucentCount;
    _instanceBuffer = [device newBufferWithBytes:world.instances
                                          length:(_opaqueCount + _translucentCount) * sizeof(VoxelInstance)
                                         options:MTLResourceStorageModeShared];
    free(world.instances);
    statsView.faceCount = _opaqueCount + _translucentCount;
    NSLog(@"Visible faces: %lu opaque, %lu water", (unsigned long)_opaqueCount, (unsigned long)_translucentCount);
    if (_opaqueDepthState == nil || _vertexBuffer == nil || _indexBuffer == nil || _instanceBuffer == nil) {
        NSLog(@"Could not create Metal render resources");
        return nil;
    }

    _materials = load_materials(device, _commandQueue);
    if (_materials == nil) {
        return nil;
    }

    MTLSamplerDescriptor* samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterNearest;
    samplerDescriptor.mipFilter = MTLSamplerMipFilterLinear;
    samplerDescriptor.maxAnisotropy = 8;
    _sampler = [device newSamplerStateWithDescriptor:samplerDescriptor];
    if (_sampler == nil) {
        NSLog(@"Could not create Metal sampler");
        return nil;
    }
    return self;
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {
    (void)view;
    (void)size;
    // The projection is rebuilt from the drawable size on every frame.
}

- (void)drawInMTKView:(MTKView*)view {
    @autoreleasepool {
        MTLRenderPassDescriptor* renderPass = view.currentRenderPassDescriptor;
        id<CAMetalDrawable> drawable = view.currentDrawable;
        CGSize size = view.drawableSize;
        if (renderPass == nil || drawable == nil || size.width == 0 || size.height == 0) {
            return;
        }

        CFTimeInterval timestamp = CACurrentMediaTime();
        CFTimeInterval frameTime = timestamp - _lastFrameTime;
        _lastFrameTime = timestamp;
        // Ignore the gap left by a pause so the animation resumes without jumping.
        if (frameTime > 0 && frameTime < 0.25) {
            _animationTime += frameTime;
            _fpsFrameCount++;
        } else {
            _fpsSampleTime = timestamp;
            _fpsFrameCount = 0;
        }
        CFTimeInterval fpsInterval = timestamp - _fpsSampleTime;
        if (fpsInterval >= 1.0) {
            _statsView.framesPerSecond = (double)_fpsFrameCount / fpsInterval;
            _fpsFrameCount = 0;
            _fpsSampleTime = timestamp;
        }

        // Orbit the whole diorama around its vertical center.
        float angle = (float)_animationTime * 0.16f;
        vector_float3 target = {WorldSize * 0.5f, WorldSize * 0.34f, WorldSize * 0.5f};
        vector_float3 eye = {
            target.x + sinf(angle) * 88.0f,
            target.y + 58.0f,
            target.z + cosf(angle) * 88.0f,
        };
        matrix_float4x4 viewMatrix = matrix_look_at(eye, target, (vector_float3){0, 1, 0});
        matrix_float4x4 projectionMatrix =
            matrix_perspective(50.0f * (float)M_PI / 180.0f, (float)(size.width / size.height), 1.0f, 500.0f);
        Uniforms uniforms = {
            .viewProjectionMatrix = simd_mul(projectionMatrix, viewMatrix),
            .cameraPosition = eye,
            .sunDirection = simd_normalize((vector_float3){0.45f, 0.78f, 0.30f}),
            .skyColor = skyColor,
            .ambient = 0.42f,
            .translucentAlpha = 0.60f,
            .fogStart = 120.0f,
            .fogEnd = 300.0f,
        };

        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        commandBuffer.label = @"Blocks Frame";
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
        encoder.label = @"Blocks Render Pass";
        [encoder setFragmentBytes:&uniforms length:sizeof(uniforms) atIndex:BufferIndexUniforms];

        [encoder setRenderPipelineState:_skyPipelineState];
        [encoder setDepthStencilState:_skyDepthState];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];

        // The cube faces are wound counter-clockwise when seen from outside.
        [encoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [encoder setCullMode:MTLCullModeBack];
        [encoder setVertexBuffer:_vertexBuffer offset:0 atIndex:BufferIndexVertices];
        [encoder setVertexBuffer:_instanceBuffer offset:0 atIndex:BufferIndexInstances];
        [encoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:BufferIndexUniforms];
        [encoder setFragmentTexture:_materials atIndex:TextureIndexMaterials];
        [encoder setFragmentSamplerState:_sampler atIndex:SamplerIndexMaterials];

        [encoder setRenderPipelineState:_opaquePipelineState];
        [encoder setDepthStencilState:_opaqueDepthState];
        [self drawVoxelsWithEncoder:encoder instanceCount:_opaqueCount baseInstance:0];
        if (_translucentCount > 0) {
            [encoder setRenderPipelineState:_translucentPipelineState];
            [encoder setDepthStencilState:_translucentDepthState];
            [self drawVoxelsWithEncoder:encoder instanceCount:_translucentCount baseInstance:_opaqueCount];
        }

        [encoder endEncoding];
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}

- (void)drawVoxelsWithEncoder:(id<MTLRenderCommandEncoder>)encoder
                instanceCount:(NSUInteger)instanceCount
                 baseInstance:(NSUInteger)baseInstance {
    [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                        indexCount:sizeof(indices) / sizeof(indices[0])
                         indexType:MTLIndexTypeUInt16
                       indexBuffer:_indexBuffer
                 indexBufferOffset:0
                     instanceCount:instanceCount
                        baseVertex:0
                      baseInstance:baseInstance];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSWindow* window;
@property(nonatomic, strong) MTKView* metalView;
@property(nonatomic, strong) StatsView* statsView;
@property(nonatomic, strong) Renderer* renderer;
@property(nonatomic, strong) id displayLink;
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
    [appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit Blocks" action:@selector(terminate:) keyEquivalent:@"q"]];

    NSRect frame = NSMakeRect(0, 0, 1024, 768);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                        NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Blocks";
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
    self.metalView = [[VoxelView alloc] initWithFrame:contentView.bounds device:device];
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    self.metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    self.metalView.clearColor = MTLClearColorMake(skyColor.x, skyColor.y, skyColor.z, 1.0);
    self.metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [contentView addSubview:self.metalView];

    self.statsView = [[StatsView alloc]
        initWithFrame:NSMakeRect(NSWidth(contentView.bounds) - 140, NSHeight(contentView.bounds) - 46, 140, 46)];
    self.statsView.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    [contentView addSubview:self.statsView];
    self.window.contentView = contentView;

    self.renderer = [[Renderer alloc] initWithView:self.metalView statsView:self.statsView];
    if (self.renderer == nil) {
        [NSApp terminate:nil];
        return;
    }
    self.metalView.delegate = self.renderer;
    // MTKView's own timer settles for 60 Hz on a variable refresh rate display,
    // so a display link asks the screen for its full rate instead.
    if (@available(macOS 14.0, *)) {
        self.metalView.paused = YES;
        self.metalView.enableSetNeedsDisplay = NO;
        CADisplayLink* displayLink = [self.metalView displayLinkWithTarget:self.metalView selector:@selector(draw)];
        self.displayLink = displayLink;
        [displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    [self updateFrameRate];

    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.metalView];
    [self updateRendererPausedState];
}

- (void)updateFrameRate {
    NSInteger maximum = 60;
    if (@available(macOS 12.0, *)) {
        maximum = MAX(self.window.screen.maximumFramesPerSecond, maximum);
    }
    self.metalView.preferredFramesPerSecond = maximum;
    if (@available(macOS 14.0, *)) {
        CADisplayLink* displayLink = self.displayLink;
        displayLink.preferredFrameRateRange =
            CAFrameRateRangeMake(MinimumFramesPerSecond, (float)maximum, (float)maximum);
    }
}

- (void)windowDidChangeScreen:(NSNotification*)notification {
    (void)notification;
    [self updateFrameRate];
}

- (void)windowDidChangeOcclusionState:(NSNotification*)notification {
    (void)notification;
    [self updateRendererPausedState];
}

- (void)applicationDidBecomeActive:(NSNotification*)notification {
    (void)notification;
    [self updateRendererPausedState];
}

- (void)applicationDidResignActive:(NSNotification*)notification {
    (void)notification;
    [self updateRendererPausedState];
}

- (void)updateRendererPausedState {
    BOOL visible = (self.window.occlusionState & NSWindowOcclusionStateVisible) != 0;
    BOOL paused = !NSApp.active || !visible;
    if (@available(macOS 14.0, *)) {
        ((CADisplayLink*)self.displayLink).paused = paused;
    } else {
        self.metalView.paused = paused;
    }
}

- (void)applicationWillTerminate:(NSNotification*)notification {
    (void)notification;
    if (@available(macOS 14.0, *)) {
        [(CADisplayLink*)self.displayLink invalidate];
    }
    self.metalView.paused = YES;
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
