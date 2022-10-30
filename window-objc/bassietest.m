#import <Cocoa/Cocoa.h>

NSApplication *application;
NSWindow *window;

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Create menu
    NSMenu *menubar = [[NSMenu alloc] init];
    [application setMainMenu:menubar];

    NSMenuItem *menuBarItem = [[NSMenuItem alloc] init];
    [menubar addItem:menuBarItem];

    NSMenu *appMenu = [[NSMenu alloc] init];
    [menuBarItem setSubmenu:appMenu];

    NSMenuItem* quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit BassieTest"
        action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];

    // Create window
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1024, 768)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered
        defer:NO];
    window.title = @"BassieTest";
    CGFloat windowX = (NSWidth(window.screen.frame) - NSWidth(window.frame)) / 2;
    CGFloat windowY = (NSHeight(window.screen.frame) - NSHeight(window.frame)) / 2;
    [window setFrame:NSMakeRect(windowX, windowY, NSWidth(window.frame), NSHeight(window.frame)) display:YES];
    window.minSize = NSMakeSize(320, 240);
    window.backgroundColor = [NSColor colorWithRed:0 green:0.5 blue:0.5 alpha:1];
    [window makeKeyAndOrderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
}
@end

int main(void) {
    application = [NSApplication sharedApplication];
    AppDelegate *delegate = [[AppDelegate alloc] init];
    [application setDelegate:delegate];
    [application run];
    return EXIT_SUCCESS;
}
