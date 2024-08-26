#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@end

NSApplication *application;
NSWindow *window;
AppDelegate *app_delegate;
#define LABEL_SIZE 48
NSText *label;

@implementation AppDelegate
- (void)windowDidResize:(NSNotification *)notification {
    label.frame = NSMakeRect(0, (NSHeight(window.frame) - LABEL_SIZE) / 2.f, NSWidth(window.frame), LABEL_SIZE);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Create menu
    NSMenu *menubar = [NSMenu new];
    application.mainMenu = menubar;

    NSMenuItem *menuBarItem = [NSMenuItem new];
    [menubar addItem:menuBarItem];

    NSMenu *appMenu = [NSMenu new];
    menuBarItem.submenu = appMenu;

    NSMenuItem* quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit BassieTest"
        action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];

    // Create window
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1024, 768)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered
        defer:NO];
    window.title = @"BassieTest";
    window.titlebarAppearsTransparent = YES;
    CGFloat windowX = (NSWidth(window.screen.frame) - NSWidth(window.frame)) / 2;
    CGFloat windowY = (NSHeight(window.screen.frame) - NSHeight(window.frame)) / 2;
    [window setFrame:NSMakeRect(windowX, windowY, NSWidth(window.frame), NSHeight(window.frame)) display:YES];
    window.minSize = NSMakeSize(320, 240);
    window.backgroundColor = [NSColor colorWithRed:(0x05 / 255.f) green:(0x44 / 255.f) blue:(0x5e / 255.f) alpha:1];
    window.delegate = app_delegate;

    // Create label
    label = [[NSText alloc] initWithFrame:NSMakeRect(0, (NSHeight(window.frame) - LABEL_SIZE) / 2.f, NSWidth(window.frame), LABEL_SIZE)];
    label.string = @"Hello macOS!";
    label.font = [NSFont systemFontOfSize:LABEL_SIZE];
    label.alignment = NSTextAlignmentCenter;
    label.editable = NO;
    label.selectable = NO;
    label.drawsBackground = NO;
    [window.contentView addSubview:label];

    [window makeKeyAndOrderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}
@end

int main(void) {
    application = [NSApplication sharedApplication];
    app_delegate = [AppDelegate new];
    application.delegate = app_delegate;
    [application run];
    return EXIT_SUCCESS;
}
