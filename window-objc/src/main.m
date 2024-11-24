#import <Cocoa/Cocoa.h>

@class AppDelegate;

#define LABEL_SIZE 48
typedef struct {
    NSApplication *application;
    NSWindow *window;
    AppDelegate *appDelegate;
    NSText *label;
} App;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
    @property App *app;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Create menu
    NSMenu *menubar = [NSMenu new];
    _app->application.mainMenu = menubar;

    NSMenuItem *menuBarItem = [NSMenuItem new];
    [menubar addItem:menuBarItem];

    NSMenu *appMenu = [NSMenu new];
    menuBarItem.submenu = appMenu;

    NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit BassieTest"
        action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];

    // Create window
    _app->window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1024, 768)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered
        defer:NO];
    _app->window.title = @"BassieTest";
    _app->window.titlebarAppearsTransparent = YES;
    _app->window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    CGFloat windowX = (NSWidth(_app->window.screen.frame) - NSWidth(_app->window.frame)) / 2;
    CGFloat windowY = (NSHeight(_app->window.screen.frame) - NSHeight(_app->window.frame)) / 2;
    [_app->window setFrame:NSMakeRect(windowX, windowY, NSWidth(_app->window.frame), NSHeight(_app->window.frame)) display:YES];
    _app->window.minSize = NSMakeSize(320, 240);
    _app->window.backgroundColor = [NSColor colorWithRed:(0x05 / 255.f) green:(0x44 / 255.f) blue:(0x5e / 255.f) alpha:1];
    _app->window.frameAutosaveName = @"window";
    _app->window.delegate = _app->appDelegate;

    // Create label
    _app->label = [[NSText alloc] initWithFrame:NSMakeRect(0, (NSHeight(_app->window.frame) - LABEL_SIZE) / 2.f, NSWidth(_app->window.frame), LABEL_SIZE)];
    _app->label.string = @"Hello macOS!";
    _app->label.font = [NSFont systemFontOfSize:LABEL_SIZE];
    _app->label.alignment = NSTextAlignmentCenter;
    _app->label.editable = NO;
    _app->label.selectable = NO;
    _app->label.drawsBackground = NO;
    [_app->window.contentView addSubview:_app->label];

    [_app->window makeKeyAndOrderFront:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)windowDidResize:(NSNotification *)notification {
    _app->label.frame = NSMakeRect(0, (NSHeight(_app->window.frame) - LABEL_SIZE) / 2.f, NSWidth(_app->window.frame), LABEL_SIZE);
}

@end

int main(void) {
    App app;
    app.application = [NSApplication sharedApplication];
    app.appDelegate = [AppDelegate new];
    app.appDelegate.app = &app;
    app.application.delegate = app.appDelegate;
    [app.application run];
    return EXIT_SUCCESS;
}
