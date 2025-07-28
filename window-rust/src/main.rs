#![no_main]

use std::ffi::c_void;
use std::ptr::null;

use objc2::runtime::{AnyObject as Object, Bool, ClassBuilder, Sel};
use objc2::{class, msg_send, sel, Encode, Encoding};

// MARK: Cocoa headers
#[repr(C)]
struct CGPoint {
    x: f64,
    y: f64,
}
impl CGPoint {
    fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }
}
unsafe impl Encode for CGPoint {
    const ENCODING: Encoding = Encoding::Struct("CGPoint", &[f64::ENCODING, f64::ENCODING]);
}
type NSPoint = CGPoint;

#[repr(C)]
struct CGSize {
    width: f64,
    height: f64,
}
impl CGSize {
    fn new(width: f64, height: f64) -> Self {
        Self { width, height }
    }
}
unsafe impl Encode for CGSize {
    const ENCODING: Encoding = Encoding::Struct("CGSize", &[f64::ENCODING, f64::ENCODING]);
}
type NSSize = CGSize;

#[repr(C)]
struct CGRect {
    origin: CGPoint,
    size: CGSize,
}
impl CGRect {
    fn new(origin: CGPoint, size: CGSize) -> Self {
        Self { origin, size }
    }
}
unsafe impl Encode for CGRect {
    const ENCODING: Encoding = Encoding::Struct("CGRect", &[CGPoint::ENCODING, CGSize::ENCODING]);
}
type NSRect = CGRect;

const NS_APPLICATION_ACTIVATION_POLICY_REGULAR: i64 = 0;

const NS_WINDOW_STYLE_MASK_TITLED: u64 = 1;
const NS_WINDOW_STYLE_MASK_CLOSABLE: u64 = 2;
const NS_WINDOW_STYLE_MASK_MINIATURIZABLE: u64 = 4;
const NS_WINDOW_STYLE_MASK_RESIZABLE: u64 = 8;

const NS_BACKING_STORE_BUFFERED: u64 = 2;

const NS_UTF8_STRING_ENCODING: u64 = 4;
fn ns_string(str: impl AsRef<str>) -> *mut Object {
    let str = str.as_ref();
    unsafe {
        let ns_string: *mut Object = msg_send![class!(NSString), alloc];
        msg_send![ns_string, initWithBytes:str.as_ptr().cast::<c_void>(), length:str.len(), encoding:NS_UTF8_STRING_ENCODING]
    }
}

#[link(name = "Cocoa", kind = "framework")]
extern "C" {
    static NSApp: *mut Object;
    static NSAppearanceNameDarkAqua: *const Object;
    static NSFontAttributeName: *const Object;
    static NSForegroundColorAttributeName: *const Object;
}

// MARK: CanvasView
extern "C" fn canvas_view_draw_rect(this: *mut Object, _: Sel, _dirty_rect: NSRect) {
    unsafe {
        let text: *mut Object = ns_string("Hello macOS!");

        let keys: [*const Object; 2] = [NSFontAttributeName, NSForegroundColorAttributeName];
        let values: [*const Object; 2] = [
            msg_send![class!(NSFont), systemFontOfSize:48.0],
            msg_send![class!(NSColor), whiteColor],
        ];
        let attributes: *mut Object = msg_send![class!(NSDictionary), dictionaryWithObjects:values.as_ptr(), forKeys:keys.as_ptr(), count:keys.len()];

        let size: NSSize = msg_send![text, sizeWithAttributes:attributes];
        let frame: NSRect = msg_send![this, frame];
        let rect = NSRect::new(
            NSPoint::new(
                (frame.size.width - size.width) / 2.0,
                (frame.size.height - size.height) / 2.0,
            ),
            size,
        );
        let _: () = msg_send![text, drawInRect:rect, withAttributes:attributes];
    }
}

// MARK: AppDelegate
extern "C" fn did_finish_launching(_: *mut Object, _: Sel, _: *const Object) {
    unsafe {
        // Create menu
        let menubar: *mut Object = msg_send![class!(NSMenu), new];
        let _: () = msg_send![NSApp, setMainMenu:menubar];

        let menu_bar_item: *mut Object = msg_send![class!(NSMenuItem), new];
        let _: () = msg_send![menubar, addItem:menu_bar_item];

        let app_menu: *mut Object = msg_send![class!(NSMenu), new];
        let _: () = msg_send![menu_bar_item, setSubmenu:app_menu];

        let about_menu_item: *mut Object = msg_send![class!(NSMenuItem), alloc];
        let about_menu_item: *mut Object = msg_send![about_menu_item,
            initWithTitle:ns_string("About BassieTest"),
            action:sel!(openAbout:),
            keyEquivalent:ns_string("")];
        let _: () = msg_send![app_menu, addItem:about_menu_item];

        let separator_item: *mut Object = msg_send![class!(NSMenuItem), separatorItem];
        let _: () = msg_send![app_menu, addItem:separator_item];

        let quit_menu_item: *mut Object = msg_send![class!(NSMenuItem), alloc];
        let quit_menu_item: *mut Object = msg_send![quit_menu_item,
            initWithTitle:ns_string("Quit BassieTest"),
            action:sel!(terminate:),
            keyEquivalent:ns_string("q")];
        let _: () = msg_send![app_menu, addItem:quit_menu_item];

        // Create window
        let window: *mut Object = msg_send![class!(NSWindow), alloc];
        let window: *mut Object = msg_send![window,
            initWithContentRect:NSRect::new(NSPoint::new(0.0, 0.0), NSSize::new(1024.0, 768.0)),
            styleMask:NS_WINDOW_STYLE_MASK_TITLED | NS_WINDOW_STYLE_MASK_CLOSABLE | NS_WINDOW_STYLE_MASK_MINIATURIZABLE | NS_WINDOW_STYLE_MASK_RESIZABLE,
            backing:NS_BACKING_STORE_BUFFERED,
            defer:false];
        let _: () = msg_send![window, setTitle:ns_string("BassieTest")];
        let _: () = msg_send![window, setTitlebarAppearsTransparent:true];
        let appearance: *mut Object =
            msg_send![class!(NSAppearance), appearanceNamed:NSAppearanceNameDarkAqua];
        let _: () = msg_send![window, setAppearance:appearance];
        let screen: *mut Object = msg_send![window, screen];
        let screen_frame: NSRect = msg_send![screen, frame];
        let window_frame: NSRect = msg_send![window, frame];
        let window_x = (screen_frame.size.width - window_frame.size.width) / 2.0;
        let window_y = (screen_frame.size.height - window_frame.size.height) / 2.0;
        let _: () = msg_send![window, setFrame:NSRect::new(NSPoint::new(window_x, window_y), window_frame.size), display:true];
        let _: () = msg_send![window, setMinSize:NSSize::new(320.0, 240.0)];
        let background_color: *mut Object = msg_send![class!(NSColor), colorWithRed:(0x05 as f64) / 255.0, green:(0x44 as f64) / 255.0, blue:(0x5e as f64) / 255.0, alpha:1.0];
        let _: () = msg_send![window, setBackgroundColor:background_color];
        let _: Bool = msg_send![window, setFrameAutosaveName:ns_string("window")];

        // Create canvas
        let canvas_view: *mut Object = msg_send![class!(CanvasView), new];
        let _: () = msg_send![window, setContentView:canvas_view];

        // Show window
        let _: Bool =
            msg_send![NSApp, setActivationPolicy:NS_APPLICATION_ACTIVATION_POLICY_REGULAR];
        let _: () = msg_send![NSApp, activateIgnoringOtherApps:true];
        let _: () = msg_send![window, makeKeyAndOrderFront:null::<Object>()];
    }
}

extern "C" fn should_terminate_after_last_window_closed(
    _: *mut Object,
    _: Sel,
    _: *const Object,
) -> Bool {
    Bool::YES
}

extern "C" fn open_about(_: *mut Object, _: Sel, _: *const Object) {
    unsafe {
        let _: () = msg_send![NSApp, orderFrontStandardAboutPanel:null::<c_void>()];
    }
}

// MARK: Main
#[no_mangle]
pub extern "C" fn main() {
    // Register classes
    let mut decl = ClassBuilder::new(c"CanvasView", class!(NSView)).unwrap();
    unsafe {
        decl.add_method(
            sel!(drawRect:),
            canvas_view_draw_rect as extern "C" fn(_, _, _),
        )
    };
    decl.register();

    let mut decl = ClassBuilder::new(c"AppDelegate", class!(NSObject)).unwrap();
    unsafe {
        decl.add_method(
            sel!(applicationDidFinishLaunching:),
            did_finish_launching as extern "C" fn(_, _, _),
        );
        decl.add_method(
            sel!(applicationShouldTerminateAfterLastWindowClosed:),
            should_terminate_after_last_window_closed as extern "C" fn(_, _, _) -> _,
        );
        decl.add_method(sel!(openAbout:), open_about as extern "C" fn(_, _, _));
    }
    decl.register();

    // Start application
    unsafe {
        let app: *mut Object = msg_send![class!(NSApplication), sharedApplication];
        let delegate: *mut Object = msg_send![class!(AppDelegate), new];
        let _: () = msg_send![app, setDelegate:delegate];
        let _: () = msg_send![app, run];
    }
}
