use std::ptr;

use objc::declare::ClassDecl;
use objc::runtime::{Object, Sel, NO};
use objc::{class, msg_send, sel, sel_impl};

const DELEGATE_IVAR: &str = "_delegate";

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
#[allow(dead_code)]
pub struct NSString(*mut Object);
impl NSString {
    pub fn from_str(str: impl AsRef<str>) -> Self {
        unsafe {
            let ns_string: &mut Object = msg_send![class!(NSString), alloc];
            msg_send![ns_string, initWithBytes:str.as_ref().as_ptr() length:str.as_ref().len() encoding:NS_UTF8_STRING_ENCODING]
        }
    }
}
impl Drop for NSString {
    fn drop(&mut self) {
        unsafe { msg_send![self.0, release] }
    }
}

// NSURL
pub struct NSURL(*mut Object);

// NSURLRequest
pub struct NSURLRequest(pub *mut Object);
impl NSURLRequest {
    pub fn request_with_url(url: NSURL) -> Self {
        unsafe { msg_send![class!(NSURLRequest), requestWithURL:url.0] }
    }
}

// NSBundle
pub struct NSBundle(*mut Object);
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
            msg_send![self.0, URLForResource:NSString::from_str(name).0 withExtension:NSString::from_str(ext).0]
        }
    }
}

// NSMenu
pub struct NSMenu(*mut Object);
impl NSMenu {
    pub fn new() -> Self {
        unsafe { msg_send![class!(NSMenu), new] }
    }
    pub fn add_item(&self, item: NSMenuItem) {
        unsafe { msg_send![self.0, addItem:item.0] }
    }
}

// NSMenuItem
pub struct NSMenuItem(*mut Object);
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
            let ns_menu_item: &mut Object = msg_send![class!(NSMenuItem), alloc];
            msg_send![ns_menu_item, initWithTitle:NSString::from_str(title).0 action:action keyEquivalent:NSString::from_str(key).0]
        }
    }
    pub fn set_submenu(&self, submenu: NSMenu) {
        unsafe { msg_send![self.0, setSubmenu:submenu.0] }
    }
}

// NSApplicationDelegate
pub trait NSApplicationDelegate {
    fn did_finish_launching(&self);
    fn should_terminate_after_last_window_closed(&self) -> bool;
}
extern "C" fn did_finish_launching<T: NSApplicationDelegate>(
    this: &Object,
    _: Sel,
    _: *mut Object,
) {
    unsafe {
        let delegate_ptr: usize = *this.get_ivar(DELEGATE_IVAR);
        (*(delegate_ptr as *const T)).did_finish_launching();
    }
}
extern "C" fn should_terminate_after_last_window_closed<T: NSApplicationDelegate>(
    this: &Object,
    _: Sel,
    _: *mut Object,
) -> bool {
    unsafe {
        let delegate_ptr: usize = *this.get_ivar(DELEGATE_IVAR);
        (*(delegate_ptr as *const T)).should_terminate_after_last_window_closed()
    }
}

// NSApplication
pub struct NSApplication {
    object: *mut Object,
}

impl NSApplication {
    pub fn shared_application() -> Self {
        unsafe { msg_send![class!(NSApplication), sharedApplication] }
    }
    pub fn set_delegate<T: NSApplicationDelegate>(&self, delegate: T) {
        let mut decl = ClassDecl::new("AppDelegate", class!(NSObject)).unwrap();
        decl.add_ivar::<usize>(DELEGATE_IVAR);
        unsafe {
            decl.add_method(
                sel!(applicationDidFinishLaunching:),
                did_finish_launching::<T> as extern "C" fn(&Object, Sel, *mut Object),
            );
            decl.add_method(
                sel!(applicationShouldTerminateAfterLastWindowClosed:),
                should_terminate_after_last_window_closed::<T>
                    as extern "C" fn(&Object, Sel, *mut Object) -> bool,
            );
        }
        let delegate_class = decl.register();
        unsafe {
            let app_delegate: &mut Object = msg_send![delegate_class, new];
            app_delegate
                .set_ivar::<usize>(DELEGATE_IVAR, Box::into_raw(Box::new(delegate)) as usize);
            msg_send![self.object, setDelegate:app_delegate]
        }
    }
    pub fn set_main_menu(&self, menu: NSMenu) {
        unsafe { msg_send![self.object, setMainMenu:menu.0] }
    }
    pub fn run(&self) {
        unsafe { msg_send![self.object, run] }
    }
}

// NSScreen
pub struct NSScreen(*mut Object);
impl NSScreen {
    pub fn frame(&self) -> NSRect {
        unsafe { msg_send![self.0, frame] }
    }
}

// NSView
pub struct NSView(*mut Object);
impl NSView {
    pub fn bounds(&self) -> NSRect {
        unsafe { msg_send![self.0, bounds] }
    }
    pub fn add_subview(&self, subview: *mut Object) {
        unsafe { msg_send![self.0, addSubview:subview] }
    }
}

// NSWindowDelegate
pub trait NSWindowDelegate {
    fn did_resize(&self);
}
extern "C" fn did_resize<T: NSWindowDelegate>(this: &Object, _: Sel, _: *mut Object) {
    unsafe {
        let delegate_ptr: usize = *this.get_ivar(DELEGATE_IVAR);
        (*(delegate_ptr as *const T)).did_resize();
    }
}

// NSWindow
pub const NS_WINDOW_STYLE_MASK_TITLED: i32 = 1 << 0;
pub const NS_WINDOW_STYLE_MASK_CLOSABLE: i32 = 1 << 1;
pub const NS_WINDOW_STYLE_MASK_MINIATURIZABLE: i32 = 1 << 2;
pub const NS_WINDOW_STYLE_MASK_RESIZABLE: i32 = 1 << 3;
pub const NS_BACKING_STORE_BUFFERED: i32 = 2;
pub struct NSWindow(*mut Object);
impl NSWindow {
    pub fn new() -> Self {
        unsafe {
            let ns_window: &mut Object = msg_send![class!(NSWindow), alloc];
            msg_send![ns_window, initWithContentRect:NSRect::new(0.0, 0.0, 1024.0, 768.0)
                styleMask:(NS_WINDOW_STYLE_MASK_TITLED | NS_WINDOW_STYLE_MASK_CLOSABLE | NS_WINDOW_STYLE_MASK_MINIATURIZABLE | NS_WINDOW_STYLE_MASK_RESIZABLE)
                backing:NS_BACKING_STORE_BUFFERED
                defer:NO]
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
        unsafe { msg_send![self.0, setFrame:frame display:display] }
    }
    pub fn screen(&self) -> NSScreen {
        unsafe { msg_send![self.0, screen] }
    }
    pub fn content_view(&self) -> NSView {
        unsafe { msg_send![self.0, contentView] }
    }
    pub fn set_delegate_from_ref<T: NSWindowDelegate>(&self, delegate: &T) {
        let mut decl = ClassDecl::new("WindowDelegate", class!(NSObject)).unwrap();
        decl.add_ivar::<usize>(DELEGATE_IVAR);
        unsafe {
            decl.add_method(
                sel!(windowDidResize:),
                did_resize::<T> as extern "C" fn(&Object, Sel, *mut Object),
            );
        }
        let delegate_class = decl.register();
        unsafe {
            let window_delegate: &mut Object = msg_send![delegate_class, new];
            window_delegate.set_ivar::<usize>(DELEGATE_IVAR, delegate as *const T as usize);
            msg_send![self.0, setDelegate:window_delegate]
        }
    }
    pub fn set_frame_autosave_name(&self, name: impl AsRef<str>) {
        unsafe { msg_send![self.0, setFrameAutosaveName:NSString::from_str(name).0] }
    }
    pub fn make_key_and_order_front(&self) {
        unsafe { msg_send![self.0, makeKeyAndOrderFront:ptr::null::<*const Object>()] }
    }
}
impl Default for NSWindow {
    fn default() -> Self {
        Self::new()
    }
}

// WKWebView
pub struct WKWebView(pub *mut Object);
impl WKWebView {
    pub fn new() -> Self {
        unsafe { msg_send![class!(WKWebView), new] }
    }
    pub fn set_frame(&self, frame: NSRect) {
        unsafe { msg_send![self.0, setFrame:frame] }
    }
    pub fn load_request(&self, request: *mut Object) {
        unsafe { msg_send![self.0, loadRequest:request] }
    }
}
impl Default for WKWebView {
    fn default() -> Self {
        Self::new()
    }
}
