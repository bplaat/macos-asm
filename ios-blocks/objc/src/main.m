#import <ImageIO/ImageIO.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "shader_types.h"
#import "world.h"

static const unsigned char embeddedMetallib[] = {
#embed "default.metallib"
};

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
            materials = nil;
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

@interface StatsLabel : UILabel
@property(nonatomic) double framesPerSecond;
@property(nonatomic) NSUInteger faceCount;
@end

@implementation StatsLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
        self.textColor = UIColor.whiteColor;
        self.textAlignment = NSTextAlignmentRight;
        self.numberOfLines = 2;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.65f;
        self.layer.shadowRadius = 3;
        self.layer.shadowOffset = CGSizeZero;
        [self updateText];
    }
    return self;
}

- (void)setFramesPerSecond:(double)framesPerSecond {
    _framesPerSecond = framesPerSecond;
    [self updateText];
}

- (void)setFaceCount:(NSUInteger)faceCount {
    _faceCount = faceCount;
    [self updateText];
}

- (void)updateText {
    self.text = [NSString stringWithFormat:@"%.0f FPS\n%lu faces", _framesPerSecond, (unsigned long)_faceCount];
}

@end

@interface Renderer : NSObject <MTKViewDelegate>
- (nullable instancetype)initWithView:(MTKView*)view statsView:(StatsLabel*)statsView;
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
    __weak StatsLabel* _statsView;
    NSUInteger _opaqueCount;
    NSUInteger _translucentCount;
    CFTimeInterval _animationTime;
    CFTimeInterval _lastFrameTime;
    CFTimeInterval _fpsSampleTime;
    NSUInteger _fpsFrameCount;
}

- (nullable instancetype)initWithView:(MTKView*)view statsView:(StatsLabel*)statsView {
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
@interface BlocksViewController : UIViewController
@property(nonatomic, strong) MTKView* metalView;
@property(nonatomic, strong) Renderer* renderer;
@property(nonatomic, strong) CADisplayLink* displayLink;
- (void)updateFrameRate;
- (void)setRenderingPaused:(BOOL)paused;
@end

@implementation BlocksViewController

- (void)loadView {
    self.view = [UIView new];
    self.view.backgroundColor = UIColor.blackColor;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) {
        NSLog(@"Metal is not supported on this device");
        return;
    }
    NSLog(@"Metal device: %@", device.name);

    self.metalView = [[MTKView alloc] initWithFrame:self.view.bounds device:device];
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    self.metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    self.metalView.clearColor = MTLClearColorMake(skyColor.x, skyColor.y, skyColor.z, 1.0);
    self.metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.metalView.paused = YES;
    self.metalView.enableSetNeedsDisplay = NO;
    [self.view addSubview:self.metalView];

    StatsLabel* stats = [StatsLabel new];
    stats.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stats];
    [NSLayoutConstraint activateConstraints:@[
        [stats.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [stats.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [stats.widthAnchor constraintEqualToConstant:130],
    ]];

    self.renderer = [[Renderer alloc] initWithView:self.metalView statsView:stats];
    if (self.renderer == nil) {
        NSLog(@"Could not initialize the blocks renderer");
        return;
    }
    self.metalView.delegate = self.renderer;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateFrameRate];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.renderer == nil) {
        return;
    }
    if (self.displayLink == nil) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawFrame:)];
        [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    [self updateFrameRate];
    [self setRenderingPaused:self.view.window.windowScene.activationState != UISceneActivationStateForegroundActive];
}

- (void)updateFrameRate {
    if (self.displayLink == nil || self.view.window == nil) {
        return;
    }
    NSInteger maximum = MAX(self.view.window.screen.maximumFramesPerSecond, 60);
    self.displayLink.preferredFrameRateRange = CAFrameRateRangeMake(30.0f, (float)maximum, (float)maximum);
}

- (void)drawFrame:(CADisplayLink*)displayLink {
    (void)displayLink;
    [self.metalView draw];
}

- (void)setRenderingPaused:(BOOL)paused {
    self.displayLink.paused = paused;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.displayLink invalidate];
    self.displayLink = nil;
}

@end

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow* window;
@end

@implementation SceneDelegate

- (void)scene:(UIScene*)scene willConnectToSession:(UISceneSession*)session options:(UISceneConnectionOptions*)options {
    (void)session;
    (void)options;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene*)scene];
    self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.window.rootViewController = [BlocksViewController new];
    [self.window makeKeyAndVisible];
}

- (void)sceneDidBecomeActive:(UIScene*)scene {
    (void)scene;
    BlocksViewController* controller = (BlocksViewController*)self.window.rootViewController;
    [controller setRenderingPaused:NO];
}

- (void)sceneWillResignActive:(UIScene*)scene {
    (void)scene;
    BlocksViewController* controller = (BlocksViewController*)self.window.rootViewController;
    [controller setRenderingPaused:YES];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation AppDelegate
@end

int main(int argc, char** argv) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
