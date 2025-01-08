#![no_main]

use std::ffi::c_void;
use std::ptr::null;

use objc::*;

// MARK: Cocoa headers
#[repr(C)]
struct NSSize {
    width: f64,
    height: f64,
}
impl NSSize {
    fn new(width: f64, height: f64) -> Self {
        Self { width, height }
    }
}

#[repr(C)]
struct NSRect {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
}
impl NSRect {
    fn new(x: f64, y: f64, width: f64, height: f64) -> Self {
        Self {
            x,
            y,
            width,
            height,
        }
    }
}

const NS_APPLICATION_ACTIVATION_POLICY_REGULAR: i32 = 0;

const NS_WINDOW_STYLE_MASK_TITLED: u32 = 1;
const NS_WINDOW_STYLE_MASK_CLOSABLE: u32 = 2;
const NS_WINDOW_STYLE_MASK_MINIATURIZABLE: u32 = 4;
const NS_WINDOW_STYLE_MASK_RESIZABLE: u32 = 8;

const NS_BACKING_STORE_BUFFERED: u32 = 2;

const NS_UTF8_STRING_ENCODING: i32 = 4;
fn ns_string(str: impl AsRef<str>) -> Object {
    unsafe {
        let ns_string: Object = msg_send![msg_send![class!(NSString), alloc], initWithBytes:str.as_ref().as_ptr() length:str.as_ref().len() encoding:NS_UTF8_STRING_ENCODING];
        msg_send![ns_string, autorelease]
    }
}

extern "C" {
    static NSApp: Object;
    static NSAppearanceNameDarkAqua: Object;
    static NSFontAttributeName: Object;
    static NSForegroundColorAttributeName: Object;
}

// MARK: CanvasView
extern "C" fn canvas_view_draw_rect(this: Object, _: Sel, _dirty_rect: NSRect) {
    unsafe {
        let text: Object = ns_string("Hello macOS!");

        let values: [Object; 2] = [
            msg_send![class!(NSFont), systemFontOfSize:48.0],
            msg_send![class!(NSColor), whiteColor],
        ];
        let keys: [Object; 2] = [NSFontAttributeName, NSForegroundColorAttributeName];
        let attributes: Object = msg_send![class!(NSDictionary), dictionaryWithObjects:&values forKeys:&keys count:values.len()];

        let size: NSSize = msg_send![text, sizeWithAttributes:attributes];
        let frame: NSRect = msg_send![this, frame];
        let rect = NSRect::new(
            (frame.width - size.width) / 2.0,
            (frame.height - size.height) / 2.0,
            size.width,
            size.height,
        );
        let _: () = msg_send![text, drawInRect:rect withAttributes:attributes];
    }
}

// MARK: AppDelegate
extern "C" fn did_finish_launching(_this: Object, _: Sel, _: Object) {
    unsafe {
        // Create menu
        let menubar: Object = msg_send![class!(NSMenu), new];
        let _: () = msg_send![NSApp, setMainMenu:menubar];

        let menu_bar_item: Object = msg_send![class!(NSMenuItem), new];
        let _: () = msg_send![menubar, addItem:menu_bar_item];

        let app_menu: Object = msg_send![class!(NSMenu), new];
        let _: () = msg_send![menu_bar_item, setSubmenu:app_menu];

        let quit_menu_item: Object = msg_send![msg_send![class!(NSMenuItem), alloc],
            initWithTitle:ns_string("Quit BassieTest")
            action:sel!(terminate:)
            keyEquivalent:ns_string("q")];
        let _: () = msg_send![app_menu, addItem:quit_menu_item];

        // Create window
        let window: Object = msg_send![msg_send![class!(NSWindow), alloc],
            initWithContentRect:NSRect::new(0.0, 0.0, 1024.0, 768.0)
            styleMask:NS_WINDOW_STYLE_MASK_TITLED | NS_WINDOW_STYLE_MASK_CLOSABLE | NS_WINDOW_STYLE_MASK_MINIATURIZABLE | NS_WINDOW_STYLE_MASK_RESIZABLE
            backing:NS_BACKING_STORE_BUFFERED
            defer:false];
        let _: () = msg_send![window, setTitle:ns_string("BassieTest")];
        let _: () = msg_send![window, setTitlebarAppearsTransparent:true];
        let appearance: Object =
            msg_send![class!(NSAppearance), appearanceNamed:NSAppearanceNameDarkAqua];
        let _: () = msg_send![window, setAppearance:appearance];
        let screen_frame: NSRect = msg_send![msg_send![window, screen], frame];
        let window_frame: NSRect = msg_send![window, frame];
        let window_x = (screen_frame.width - window_frame.width) / 2.0;
        let window_y = (screen_frame.height - window_frame.height) / 2.0;
        let _: () = msg_send![window, setFrame:NSRect::new(window_x, window_y, window_frame.width, window_frame.height) display:true];
        let _: () = msg_send![window, setMinSize:NSSize::new(320.0, 240.0)];
        let background_color: Object = msg_send![class!(NSColor), colorWithRed:(0x05 as f64) / 255.0 green:(0x44 as f64) / 255.0 blue:(0x5e as f64) / 255.0 alpha:1.0];
        let _: () = msg_send![window, setBackgroundColor:background_color];
        let _: () = msg_send![window, setFrameAutosaveName:ns_string("window")];

        // Create canvas
        let canvas_view: Object = msg_send![class!(CanvasView), new];
        let _: () = msg_send![window, setContentView:canvas_view];

        // Show window
        let _: () = msg_send![NSApp, setActivationPolicy:NS_APPLICATION_ACTIVATION_POLICY_REGULAR];
        let _: () = msg_send![NSApp, activateIgnoringOtherApps:true];
        let _: () = msg_send![window, makeKeyAndOrderFront:null::<c_void>()];
    }
}

extern "C" fn should_terminate_after_last_window_closed(_: Object, _: Sel, _: Object) -> bool {
    true
}

// MARK: Main
#[no_mangle]
pub extern "C" fn main() {
    // Register classes
    let mut decl = ClassDecl::new("CanvasView", class!(NSView)).unwrap();
    decl.add_method(
        sel!(drawRect:),
        canvas_view_draw_rect as *const c_void,
        "v@:{NSRect={CGPoint=dd}{CGSize=dd}}",
    );
    decl.register();

    let mut decl = ClassDecl::new("AppDelegate", class!(NSObject)).unwrap();
    decl.add_method(
        sel!(applicationDidFinishLaunching:),
        did_finish_launching as *const c_void,
        "v@:@",
    );
    decl.add_method(
        sel!(applicationShouldTerminateAfterLastWindowClosed:),
        should_terminate_after_last_window_closed as *const c_void,
        "B@:@",
    );
    decl.register();

    // Start application
    unsafe {
        let app = msg_send![class!(NSApplication), sharedApplication];
        let delegate: Object = msg_send![class!(AppDelegate), new];
        let _: () = msg_send![app, setDelegate:delegate];
        let _: () = msg_send![app, run];
    }
}
