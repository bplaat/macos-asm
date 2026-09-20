#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

#import "shader_types.h"

static const unsigned char embeddedMetallib[] = {
#embed "default.metallib"
};

static const Vertex vertices[] = {
    {.position = {0.0f, 0.75f}, .color = {1.0f, 0.1f, 0.1f, 1.0f}},
    {.position = {-0.7f, -0.6f}, .color = {0.1f, 1.0f, 0.2f, 1.0f}},
    {.position = {0.7f, -0.6f}, .color = {0.1f, 0.3f, 1.0f, 1.0f}},
};

@interface Renderer : NSObject <MTKViewDelegate>
- (nullable instancetype)initWithView:(MTKView*)view;
@end

@implementation Renderer {
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
}

- (nullable instancetype)initWithView:(MTKView*)view {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    id<MTLDevice> device = view.device;
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
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;

    _pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (_pipelineState == nil) {
        NSLog(@"Could not create Metal pipeline: %@", error);
        return nil;
    }

    _commandQueue = [device newCommandQueue];
    return self;
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {
    (void)view;
    (void)size;
}

- (void)drawInMTKView:(MTKView*)view {
    @autoreleasepool {
        MTLRenderPassDescriptor* renderPass = view.currentRenderPassDescriptor;
        id<CAMetalDrawable> drawable = view.currentDrawable;
        if (renderPass == nil || drawable == nil) {
            return;
        }

        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        commandBuffer.label = @"Rainbow Triangle";

        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
        encoder.label = @"Triangle Render Pass";
        [encoder setRenderPipelineState:_pipelineState];
        [encoder setVertexBytes:vertices length:sizeof(vertices) atIndex:BufferIndexVertices];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];

        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow* window;
@property(nonatomic, strong) Renderer* renderer;
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

    NSRect frame = NSMakeRect(0, 0, 1024, 768);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                        NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Triangle";
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
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
    NSString* metalVersion = @"2 or earlier";
    if (@available(macOS 26.0, *)) {
        if ([device supportsFamily:MTLGPUFamilyMetal4]) {
            metalVersion = @"4";
        }
    }
    if ([metalVersion isEqualToString:@"2 or earlier"]) {
        if (@available(macOS 13.0, *)) {
            if ([device supportsFamily:MTLGPUFamilyMetal3]) {
                metalVersion = @"3";
            }
        }
    }
    NSLog(@"Metal version: %@, device: %@", metalVersion, device.name);

    MTKView* metalView = [[MTKView alloc] initWithFrame:self.window.contentView.bounds device:device];
    metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    metalView.clearColor = MTLClearColorMake(0.015, 0.02, 0.04, 1.0);
    metalView.preferredFramesPerSecond = 60;

    self.renderer = [[Renderer alloc] initWithView:metalView];
    if (self.renderer == nil) {
        [NSApp terminate:nil];
        return;
    }
    metalView.delegate = self.renderer;
    self.window.contentView = metalView;

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
