use std::ffi::{c_char, c_void, CStr};
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
        let str = str.as_ref();
        unsafe {
            let ns_string: Object = msg_send![class!(NSString), alloc];
            let ns_string: Object = msg_send![ns_string, initWithBytes:str.as_ptr() length:str.len() encoding:NS_UTF8_STRING_ENCODING];
            msg_send![ns_string, autorelease]
        }
    }

    pub fn to_string(&self) -> String {
        unsafe {
            let bytes: *const c_char = msg_send![self.0, UTF8String];
            let len: usize = msg_send![self.0, lengthOfBytesUsingEncoding:NS_UTF8_STRING_ENCODING];
            let slice = std::slice::from_raw_parts(bytes as *const u8, len as usize);
            String::from_utf8_lossy(slice).to_string()
        }
    }
}

// NSURL
#[allow(clippy::upper_case_acronyms)]
pub struct NSURL(Object);

// NSURLRequest
pub struct NSURLRequest(Object);
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
            msg_send![self.0, URLForResource:NSString::from_str(name).0 withExtension:NSString::from_str(ext).0]
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
            msg_send![ns_menu_item, initWithTitle:NSString::from_str(title).0 action:action keyEquivalent:NSString::from_str(key).0]
        }
    }
    pub fn set_submenu(&self, submenu: NSMenu) {
        unsafe { msg_send![self.0, setSubmenu:submenu.0] }
    }
}

// NSApplicationDelegate
pub const PTR_IVAR: &CStr = unsafe { CStr::from_bytes_with_nul_unchecked(b"ptr\0") };
pub trait NSApplicationDelegate {
    fn did_finish_launching(&self);
    fn should_terminate_after_last_window_closed(&self) -> bool;
}
extern "C" fn did_finish_launching<T: NSApplicationDelegate>(
    this: Object,
    _: Sel,
    _notification: Object,
) {
    unsafe {
        let mut app = null();
        object_getInstanceVariable(this, PTR_IVAR.as_ptr(), &mut app);
        (*(app as *const T)).did_finish_launching();
    }
}
extern "C" fn should_terminate_after_last_window_closed<T: NSApplicationDelegate>(
    this: Object,
    _: Sel,
    _sender: Object,
) -> bool {
    unsafe {
        let mut app = null();
        object_getInstanceVariable(this, PTR_IVAR.as_ptr(), &mut app);
        (*(app as *const T)).should_terminate_after_last_window_closed()
    }
}

// NSApplication
pub struct NSApplication(Object);
impl NSApplication {
    pub fn shared_application() -> Self {
        unsafe { msg_send![class!(NSApplication), sharedApplication] }
    }
    pub fn set_delegate<T: NSApplicationDelegate>(&self, delegate: &T) {
        let mut decl = ClassDecl::new("AppDelegate", class!(NSObject)).unwrap();
        decl.add_ivar::<*const c_void>(PTR_IVAR.as_ptr(), "^v");
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
        unsafe {
            let app_delegate: Object = msg_send![delegate_class, new];
            object_setInstanceVariable(
                app_delegate,
                PTR_IVAR.as_ptr(),
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
    pub fn add_subview(&self, subview: NSView) {
        unsafe { msg_send![self.0, addSubview:subview] }
    }
}

// NSWindowDelegate
pub trait NSWindowDelegate {
    fn did_resize(&self);
}
extern "C" fn did_resize<T: NSWindowDelegate>(this: Object, _: Sel, _notification: Object) {
    unsafe {
        let mut app = null();
        object_getInstanceVariable(this, PTR_IVAR.as_ptr(), &mut app);
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
            msg_send![ns_window, initWithContentRect:NSRect::new(0.0, 0.0, 1024.0, 768.0)
                styleMask:NS_WINDOW_STYLE_MASK_TITLED | NS_WINDOW_STYLE_MASK_CLOSABLE | NS_WINDOW_STYLE_MASK_MINIATURIZABLE | NS_WINDOW_STYLE_MASK_RESIZABLE
                backing:NS_BACKING_STORE_BUFFERED
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
        unsafe { msg_send![self.0, setFrame:frame display:display] }
    }
    pub fn screen(&self) -> NSScreen {
        unsafe { msg_send![self.0, screen] }
    }
    pub fn content_view(&self) -> NSView {
        unsafe { msg_send![self.0, contentView] }
    }
    pub fn set_delegate<T: NSWindowDelegate>(&self, delegate: &T) {
        let mut decl = ClassDecl::new("WindowDelegate", class!(NSObject)).unwrap();
        decl.add_ivar::<*const c_void>(PTR_IVAR.as_ptr(), "^v");
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
                PTR_IVAR.as_ptr(),
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

// WKNavigationDelegate
pub trait WKNavigationDelegate {
    fn did_finish_navigation(&self, navigation: WKNavigation);
}
extern "C" fn did_finish_navigation<T: WKNavigationDelegate>(
    this: Object,
    _: Sel,
    _webview: Object,
    navigation: Object,
) {
    unsafe {
        let mut app = null();
        object_getInstanceVariable(this, PTR_IVAR.as_ptr(), &mut app);
        (*(app as *const T)).did_finish_navigation(WKNavigation(navigation));
    }
}

// WKNavigation
#[allow(dead_code)]
pub struct WKNavigation(Object);

// WKScriptMessageHandler
pub trait WKScriptMessageHandler {
    fn did_receive_message(&self, message: WKScriptMessage);
}
extern "C" fn did_receive_message<T: WKScriptMessageHandler>(
    this: Object,
    _: Sel,
    _user_content_controller: Object,
    message: Object,
) {
    unsafe {
        let mut app = null();
        object_getInstanceVariable(this, PTR_IVAR.as_ptr(), &mut app);
        (*(app as *const T)).did_receive_message(WKScriptMessage(message));
    }
}

// WKScriptMessage
pub struct WKScriptMessage(Object);
impl WKScriptMessage {
    pub fn body(&self) -> String {
        unsafe {
            let ns_string = NSString(msg_send![self.0, body]);
            let string = ns_string.to_string();
            string
        }
    }
}

// WKWebViewConfiguration
pub struct WKWebViewConfiguration(Object);
impl WKWebViewConfiguration {
    pub fn user_content_controller(&self) -> WKUserContentController {
        WKUserContentController(unsafe { msg_send![self.0, userContentController] })
    }
}

// WKUserContentController
pub struct WKUserContentController(Object);
impl WKUserContentController {
    pub fn add_script_message_handler<T: WKScriptMessageHandler>(
        &self,
        name: impl AsRef<str>,
        handler: &T,
    ) {
        let mut decl = ClassDecl::new("ScriptMessageHandler", class!(NSObject)).unwrap();
        decl.add_ivar::<*const c_void>(PTR_IVAR.as_ptr(), "^v");
        decl.add_method(
            sel!(userContentController:didReceiveScriptMessage:),
            did_receive_message::<T> as *const c_void,
            "v@:@",
        );
        let handler_class = decl.register();
        unsafe {
            let script_message_handler: Object = msg_send![handler_class, new];
            object_setInstanceVariable(
                script_message_handler,
                PTR_IVAR.as_ptr(),
                handler as *const _ as *mut c_void,
            );
            msg_send![self.0, addScriptMessageHandler:script_message_handler name:NSString::from_str(name).0]
        }
    }
}

// WKWebView
pub struct WKWebView(Object);
impl WKWebView {
    pub fn new() -> Self {
        unsafe { msg_send![class!(WKWebView), new] }
    }
    pub fn as_ns_view(&self) -> NSView {
        NSView(self.0)
    }
    pub fn configuration(&self) -> WKWebViewConfiguration {
        WKWebViewConfiguration(unsafe { msg_send![self.0, configuration] })
    }
    pub fn set_frame(&self, frame: NSRect) {
        unsafe { msg_send![self.0, setFrame:frame] }
    }
    pub fn set_navigation_delegate<T: WKNavigationDelegate>(&self, delegate: &T) {
        let mut decl = ClassDecl::new("NavigationDelegate", class!(NSObject)).unwrap();
        decl.add_ivar::<*const c_void>(PTR_IVAR.as_ptr(), "^v");
        decl.add_method(
            sel!(webView:didFinishNavigation:),
            did_finish_navigation::<T> as *const c_void,
            "v@:@",
        );
        let delegate_class = decl.register();
        unsafe {
            let navigation_delegate: Object = msg_send![delegate_class, new];
            object_setInstanceVariable(
                navigation_delegate,
                PTR_IVAR.as_ptr(),
                delegate as *const _ as *mut c_void,
            );
            msg_send![self.0, setNavigationDelegate:navigation_delegate]
        }
    }
    pub fn load_request(&self, request: NSURLRequest) {
        unsafe { msg_send![self.0, loadRequest:request.0] }
    }
    pub fn evaluate_javascript(&self, js: impl AsRef<str>) {
        unsafe {
            msg_send![self.0, evaluateJavaScript:NSString::from_str(js).0 completionHandler:null::<*const c_void>()]
        }
    }
}
impl Default for WKWebView {
    fn default() -> Self {
        Self::new()
    }
}
