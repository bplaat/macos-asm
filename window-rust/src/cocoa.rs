use std::ffi::{c_void, CStr};
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

// NSColor
pub struct NSColor(Object);
impl NSColor {
    pub fn from_rgba(r: u8, g: u8, b: u8, a: u8) -> Self {
        unsafe {
            msg_send![class!(NSColor), colorWithRed:r as f64 / 255.0 green:g as f64 / 255.0 blue:b as f64 / 255.0 alpha:a as f64 / 255.0]
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

// NSFont
pub struct NSFont(Object);
impl NSFont {
    pub fn system_font_of_size(size: f64) -> Self {
        unsafe { msg_send![class!(NSFont), systemFontOfSize:size] }
    }
}

// NSTextAlignment
pub type NSTextAlignment = i32;
pub const NS_TEXT_ALIGNMENT_CENTER: NSTextAlignment = 1;

// NSView
pub struct NSView(Object);
impl NSView {
    pub fn add_subview(&self, subview: NSView) {
        unsafe { msg_send![self.0, addSubview:subview] }
    }
}

// NSAppearance
pub struct NSAppearance(Object);

impl NSAppearance {
    pub fn named(name: impl AsRef<str>) -> Self {
        unsafe { msg_send![class!(NSAppearance), appearanceNamed:NSString::from_str(name).0] }
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
pub type NSWindowStyleMask = i32;
pub const NS_WINDOW_STYLE_MASK_TITLED: NSWindowStyleMask = 1;
pub const NS_WINDOW_STYLE_MASK_CLOSABLE: NSWindowStyleMask = 2;
pub const NS_WINDOW_STYLE_MASK_MINIATURIZABLE: NSWindowStyleMask = 4;
pub const NS_WINDOW_STYLE_MASK_RESIZABLE: NSWindowStyleMask = 8;

pub type NSBackingStoreType = i32;
pub const NS_BACKING_STORE_BUFFERED: NSBackingStoreType = 2;

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
    pub fn set_titlebar_appears_transparent(&self, transparent: bool) {
        unsafe { msg_send![self.0, setTitlebarAppearsTransparent:transparent] }
    }
    pub fn set_appearance(&self, appearance: NSAppearance) {
        unsafe { msg_send![self.0, setAppearance:appearance.0] }
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
    pub fn set_background_color(&self, color: NSColor) {
        unsafe { msg_send![self.0, setBackgroundColor:color.0] }
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

// NSText
pub struct NSText(Object);
impl NSText {
    pub fn new() -> Self {
        unsafe { msg_send![class!(NSText), new] }
    }
    pub fn as_ns_view(&self) -> NSView {
        NSView(self.0)
    }
    pub fn set_string(&self, string: impl AsRef<str>) {
        unsafe { msg_send![self.0, setString:NSString::from_str(string).0] }
    }
    pub fn set_frame(&self, frame: NSRect) {
        unsafe { msg_send![self.0, setFrame:frame] }
    }
    pub fn set_font(&self, font: NSFont) {
        unsafe { msg_send![self.0, setFont:font.0] }
    }
    pub fn set_alignment(&self, alignment: NSTextAlignment) {
        unsafe { msg_send![self.0, setAlignment:alignment] }
    }
    pub fn set_editable(&self, editable: bool) {
        unsafe { msg_send![self.0, setEditable:editable] }
    }
    pub fn set_selectable(&self, selectable: bool) {
        unsafe { msg_send![self.0, setSelectable:selectable] }
    }
    pub fn set_draws_background(&self, draws_background: bool) {
        unsafe { msg_send![self.0, setDrawsBackground:draws_background] }
    }
}
impl Default for NSText {
    fn default() -> Self {
        Self::new()
    }
}
