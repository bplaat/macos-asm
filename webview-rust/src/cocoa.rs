use std::ffi::{c_char, c_void};
use std::ptr::null;

use crate::objc::{object_getInstanceVariable, object_setInstanceVariable, ClassDecl, Object, Sel};
use crate::{class, msg_send, sel};

// NSSize
#[repr(C)]
pub struct NSSize {
    pub width: f64,
    pub height: f64,
}
impl NSSize {
    pub fn new(width: f64, height: f64) -> Self {
        Self { width, height }
    }
}

// NSRect
#[repr(C)]
pub struct NSRect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}
impl NSRect {
    pub fn new(x: f64, y: f64, width: f64, height: f64) -> Self {
        Self {
            x,
            y,
            width,
            height,
        }
    }
}

// NSString
pub const NS_UTF8_STRING_ENCODING: i32 = 4;
pub struct NSString(Object);
impl NSString {
    pub fn from_str(str: impl AsRef<str>) -> Self {
        unsafe {
            let ns_string: Object = msg_send![class!(NSString), alloc];
            msg_send![ns_string, initWithBytes:str.as_ref().as_ptr(), length:str.as_ref().len(), encoding:NS_UTF8_STRING_ENCODING]
        }
    }
}

// NSURL
#[allow(clippy::upper_case_acronyms)]
pub struct NSURL(Object);

// NSURLRequest
pub struct NSURLRequest(pub Object);
impl NSURLRequest {
    pub fn request_with_url(url: NSURL) -> Self {
        unsafe { msg_send![class!(NSURLRequest), requestWithURL:url.0] }
    }
}

// NSBundle
pub struct NSBundle(Object);
impl NSBundle {
    pub fn main_bundle() -> Self {
        unsafe { msg_send![class!(NSBundle), mainBundle] }
    }
    pub fn url_for_resource_with_extension(
        &self,
        name: impl AsRef<str>,
        ext: impl AsRef<str>,
    ) -> NSURL {
        unsafe {
            msg_send![self.0, URLForResource:NSString::from_str(name).0, withExtension:NSString::from_str(ext).0]
        }
    }
}

// NSMenu
pub struct NSMenu(Object);
impl NSMenu {
    pub fn new() -> Self {
        unsafe { msg_send![class!(NSMenu), new] }
    }
    pub fn add_item(&self, item: NSMenuItem) {
        unsafe { msg_send![self.0, addItem:item.0] }
    }
}

// NSMenuItem
pub struct NSMenuItem(Object);
impl NSMenuItem {
    pub fn new() -> Self {
        unsafe { msg_send![class!(NSMenuItem), new] }
    }
    pub fn new_with_title_action_and_key(
        title: impl AsRef<str>,
        action: Sel,
        key: impl AsRef<str>,
    ) -> Self {
        unsafe {
            let ns_menu_item: Object = msg_send![class!(NSMenuItem), alloc];
            msg_send![ns_menu_item, initWithTitle:NSString::from_str(title).0, action:action, keyEquivalent:NSString::from_str(key).0]
        }
    }
    pub fn set_submenu(&self, submenu: NSMenu) {
        unsafe { msg_send![self.0, setSubmenu:submenu.0] }
    }
}

// NSApplicationDelegate
pub const PTR_IVAR: &str = "ptr\0";
pub trait NSApplicationDelegate {
    fn did_finish_launching(&self);
    fn should_terminate_after_last_window_closed(&self) -> bool;
}
extern "C" fn did_finish_launching<T: NSApplicationDelegate>(this: Object, _: Sel) {
    unsafe {
        let mut app = null();
        object_getInstanceVariable(this, PTR_IVAR.as_ptr() as *const c_char, &mut app);
        (*(app as *const T)).did_finish_launching();
    }
}
extern "C" fn should_terminate_after_last_window_closed<T: NSApplicationDelegate>(
    this: Object,
    _: Sel,
) -> bool {
    unsafe {
        let mut app = null();
        object_getInstanceVariable(this, PTR_IVAR.as_ptr() as *const c_char, &mut app);
        (*(app as *const T)).should_terminate_after_last_window_closed()
    }
}

// NSApplication
pub struct NSApplication(Object);
impl NSApplication {
    pub fn shared_application() -> Self {
        unsafe { msg_send![class!(NSApplication), sharedApplication] }
    }
    pub fn set_delegate<T: NSApplicationDelegate>(&self, delegate: T) {
        let mut decl = ClassDecl::new("AppDelegate", class!(NSObject)).unwrap();
        decl.add_ivar::<*const c_void>(PTR_IVAR.as_ptr() as *const c_char, "^v");
        decl.add_method(
            sel!(applicationDidFinishLaunching:),
            did_finish_launching::<T> as *const c_void,
            "v@:",
        );
        decl.add_method(
            sel!(applicationShouldTerminateAfterLastWindowClosed:),
            should_terminate_after_last_window_closed::<T> as *const c_void,
            "B@:",
        );
        let delegate_class = decl.register();
        let delegate = Box::leak(Box::new(delegate));
        unsafe {
            let app_delegate: Object = msg_send![delegate_class, new];
            object_setInstanceVariable(
                app_delegate,
                PTR_IVAR.as_ptr() as *const c_char,
                delegate as *const T as *mut c_void,
            );
            msg_send![self.0, setDelegate:app_delegate]
        }
    }
    pub fn set_main_menu(&self, menu: NSMenu) {
        unsafe { msg_send![self.0, setMainMenu:menu.0] }
    }
    pub fn run(&self) {
        unsafe { msg_send![self.0, run] }
    }
}

// NSScreen
pub struct NSScreen(Object);
impl NSScreen {
    pub fn frame(&self) -> NSRect {
        unsafe { msg_send![self.0, frame] }
    }
}

// NSView
pub struct NSView(Object);
impl NSView {
    pub fn bounds(&self) -> NSRect {
        unsafe { msg_send![self.0, bounds] }
    }
    pub fn add_subview(&self, subview: Object) {
        unsafe { msg_send![self.0, addSubview:subview] }
    }
}

// NSWindowDelegate
pub trait NSWindowDelegate {
    fn did_resize(&self);
}
extern "C" fn did_resize<T: NSWindowDelegate>(this: Object, _: Sel) {
    unsafe {
        let mut app = null();
        object_getInstanceVariable(this, PTR_IVAR.as_ptr() as *const c_char, &mut app);
        (*(app as *const T)).did_resize()
    }
}

// NSWindow
pub const NS_WINDOW_STYLE_MASK_TITLED: i32 = 1;
pub const NS_WINDOW_STYLE_MASK_CLOSABLE: i32 = 2;
pub const NS_WINDOW_STYLE_MASK_MINIATURIZABLE: i32 = 4;
pub const NS_WINDOW_STYLE_MASK_RESIZABLE: i32 = 8;
pub const NS_BACKING_STORE_BUFFERED: i32 = 2;
pub struct NSWindow(Object);
impl NSWindow {
    pub fn new() -> Self {
        unsafe {
            let ns_window: Object = msg_send![class!(NSWindow), alloc];
            msg_send![ns_window, initWithContentRect:NSRect::new(0.0, 0.0, 1024.0, 768.0),
                styleMask:NS_WINDOW_STYLE_MASK_TITLED | NS_WINDOW_STYLE_MASK_CLOSABLE | NS_WINDOW_STYLE_MASK_MINIATURIZABLE | NS_WINDOW_STYLE_MASK_RESIZABLE,
                backing:NS_BACKING_STORE_BUFFERED,
                defer:false]
        }
    }
    pub fn set_title(&self, title: impl AsRef<str>) {
        unsafe { msg_send![self.0, setTitle:NSString::from_str(title).0] }
    }
    pub fn set_min_size(&self, min_size: NSSize) {
        unsafe { msg_send![self.0, setMinSize:min_size] }
    }
    pub fn frame(&self) -> NSRect {
        unsafe { msg_send![self.0, frame] }
    }
    pub fn set_frame(&self, frame: NSRect, display: bool) {
        unsafe { msg_send![self.0, setFrame:frame, display:display] }
    }
    pub fn screen(&self) -> NSScreen {
        unsafe { msg_send![self.0, screen] }
    }
    pub fn content_view(&self) -> NSView {
        unsafe { msg_send![self.0, contentView] }
    }
    pub fn set_delegate_from_ref<T: NSWindowDelegate>(&self, delegate: &T) {
        let mut decl = ClassDecl::new("WindowDelegate", class!(NSObject)).unwrap();
        decl.add_ivar::<*const c_void>(PTR_IVAR.as_ptr() as *const c_char, "^v");
        decl.add_method(
            sel!(windowDidResize:),
            did_resize::<T> as *const c_void,
            "v@:",
        );
        let delegate_class = decl.register();
        unsafe {
            let window_delegate: Object = msg_send![delegate_class, new];
            object_setInstanceVariable(
                window_delegate,
                PTR_IVAR.as_ptr() as *const c_char,
                delegate as *const T as *mut c_void,
            );
            msg_send![self.0, setDelegate:window_delegate]
        }
    }
    pub fn set_frame_autosave_name(&self, name: impl AsRef<str>) {
        unsafe { msg_send![self.0, setFrameAutosaveName:NSString::from_str(name).0] }
    }
    pub fn make_key_and_order_front(&self) {
        unsafe { msg_send![self.0, makeKeyAndOrderFront:null::<*const c_void>()] }
    }
}
impl Default for NSWindow {
    fn default() -> Self {
        Self::new()
    }
}

// WKWebView
pub struct WKWebView(pub Object);
impl WKWebView {
    pub fn new() -> Self {
        unsafe { msg_send![class!(WKWebView), new] }
    }
    pub fn set_frame(&self, frame: NSRect) {
        unsafe { msg_send![self.0, setFrame:frame] }
    }
    pub fn load_request(&self, request: Object) {
        unsafe { msg_send![self.0, loadRequest:request] }
    }
}
impl Default for WKWebView {
    fn default() -> Self {
        Self::new()
    }
}
