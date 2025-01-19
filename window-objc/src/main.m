#import <Cocoa/Cocoa.h>

// MARK: CanvasView
@interface CanvasView : NSView
@end

@implementation CanvasView

- (void)drawRect:(NSRect)dirtyRect {
    NSString *text = @"Hello macOS!";
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:48],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    NSSize size = [text sizeWithAttributes:attributes];
    NSRect rect = NSMakeRect((self.frame.size.width - size.width) / 2,
        (self.frame.size.height - size.height) / 2,
        size.width,
        size.height);
    [text drawInRect:rect withAttributes:attributes];
}

@end

// MARK: AppDelegate
@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Create menu
    NSMenu *menubar = [NSMenu new];
    NSApp.mainMenu = menubar;

    NSMenuItem *menuBarItem = [NSMenuItem new];
    [menubar addItem:menuBarItem];

    NSMenu *appMenu = [NSMenu new];
    menuBarItem.submenu = appMenu;

    NSMenuItem *aboutMenuItem = [[NSMenuItem alloc] initWithTitle:@"About BassieTest"
        action:@selector(openAbout:) keyEquivalent:@""];
    [appMenu addItem:aboutMenuItem];

    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit BassieTest"
        action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];

    // Create window
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1024, 768)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered
        defer:NO];
    window.title = @"BassieTest";
    window.titlebarAppearsTransparent = YES;
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    CGFloat windowX = (NSWidth(window.screen.frame) - NSWidth(window.frame)) / 2;
    CGFloat windowY = (NSHeight(window.screen.frame) - NSHeight(window.frame)) / 2;
    [window setFrame:NSMakeRect(windowX, windowY, NSWidth(window.frame), NSHeight(window.frame)) display:YES];
    window.minSize = NSMakeSize(320, 240);
    window.backgroundColor = [NSColor colorWithRed:(0x05 / 255.0) green:(0x44 / 255.0) blue:(0x5e / 255.0) alpha:1];
    window.frameAutosaveName = @"window";

    // Create canvas
    window.contentView = [CanvasView new];

    // Show window
    NSApp.activationPolicy = NSApplicationActivationPolicyRegular;
    [NSApp activateIgnoringOtherApps:YES];
    [window makeKeyAndOrderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)openAbout:(id)sender {
    [NSApp orderFrontStandardAboutPanel:nil];
}

@end

int main(void) {
    NSApplication *app = [NSApplication sharedApplication];
    app.delegate = [AppDelegate new];
    [app run];
    return EXIT_SUCCESS;
}
