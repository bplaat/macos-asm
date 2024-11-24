#import <Cocoa/Cocoa.h>

#define LABEL_SIZE 48

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
    @property (strong, nonatomic) NSWindow *window;
    @property (strong, nonatomic) NSText *label;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Create menu
    NSMenu *menubar = [NSMenu new];
    NSApp.mainMenu = menubar;

    NSMenuItem *menuBarItem = [NSMenuItem new];
    [menubar addItem:menuBarItem];

    NSMenu *appMenu = [NSMenu new];
    menuBarItem.submenu = appMenu;

    NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit BassieTest"
        action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];

    // Create window
    _window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1024, 768)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered
        defer:NO];
    _window.title = @"BassieTest";
    _window.titlebarAppearsTransparent = YES;
    _window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    CGFloat windowX = (NSWidth(_window.screen.frame) - NSWidth(_window.frame)) / 2;
    CGFloat windowY = (NSHeight(_window.screen.frame) - NSHeight(_window.frame)) / 2;
    [_window setFrame:NSMakeRect(windowX, windowY, NSWidth(_window.frame), NSHeight(_window.frame)) display:YES];
    _window.minSize = NSMakeSize(320, 240);
    _window.backgroundColor = [NSColor colorWithRed:(0x05 / 255.f) green:(0x44 / 255.f) blue:(0x5e / 255.f) alpha:1];
    _window.frameAutosaveName = @"window";
    _window.delegate = self;

    // Create label
    _label = [[NSText alloc] initWithFrame:NSMakeRect(0, (NSHeight(_window.frame) - LABEL_SIZE) / 2.f, NSWidth(_window.frame), LABEL_SIZE)];
    _label.string = @"Hello macOS!";
    _label.font = [NSFont systemFontOfSize:LABEL_SIZE];
    _label.alignment = NSTextAlignmentCenter;
    _label.editable = NO;
    _label.selectable = NO;
    _label.drawsBackground = NO;
    [_window.contentView addSubview:_label];

    [_window makeKeyAndOrderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)windowDidResize:(NSNotification *)notification {
    _label.frame = NSMakeRect(0, (NSHeight(_window.frame) - LABEL_SIZE) / 2.f, NSWidth(_window.frame), LABEL_SIZE);
}

@end

int main(void) {
    NSApplication *app = [NSApplication sharedApplication];
    app.delegate = [AppDelegate new];
    [app run];
    return EXIT_SUCCESS;
}
