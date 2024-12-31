use std::env;
use std::ffi::CString;
use std::os::raw::c_char;
use std::ptr::null;

use objc::*;

// CGRect
#[repr(C)]
pub struct CGRect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

// NSString
pub const NS_UTF8_STRING_ENCODING: i32 = 4;
pub struct NSString(pub Object);
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

// NSTextAlignment
#[repr(i64)]
pub enum NSTextAlignment {
    Center = 1,
}

// NSLog
extern "C" {
    pub fn NSLog(format: Object, ...);
}

// UIApplicationMain
extern "C" {
    pub fn UIApplicationMain(
        argc: i32,
        argv: *const *mut c_char,
        principalClassName: Object,
        delegateClassName: Object,
    );
}
pub fn ui_application_main(class_name: &str) {
    let argc = env::args().count() as i32;
    let argv = env::args()
        .map(|arg| CString::new(arg).unwrap().into_raw())
        .collect::<Vec<*mut c_char>>();
    unsafe {
        UIApplicationMain(
            argc,
            argv.as_ptr(),
            null(),
            NSString::from_str(class_name).0,
        );
    }
}

// UIColor
pub struct UIColor(pub Object);

impl UIColor {
    pub fn from_rgba(r: u8, g: u8, b: u8, a: u8) -> Self {
        unsafe {
            let color: Object = msg_send![class!(UIColor), alloc];
            msg_send![color, initWithRed:r as f64 / 255.0 green:g as f64 / 255.0 blue:b as f64 / 255.0 alpha:a as f64 / 255.0]
        }
    }
}

// UIFont
pub struct UIFont(pub Object);

impl UIFont {
    pub fn system_font_of_size(size: f64) -> Self {
        unsafe { msg_send![class!(UIFont), systemFontOfSize:size] }
    }
}

// UIScreen
pub struct UIScreen(Object);

impl UIScreen {
    pub fn main_screen() -> Self {
        unsafe { msg_send![class!(UIScreen), mainScreen] }
    }

    pub fn bounds(&self) -> CGRect {
        unsafe { msg_send![self.0, bounds] }
    }
}

// UIView
pub struct UIView(pub Object);

impl UIView {
    pub fn bounds(&self) -> CGRect {
        unsafe { msg_send![self.0, bounds] }
    }

    pub fn set_frame(&self, frame: CGRect) {
        unsafe { msg_send![self.0, setFrame:frame] }
    }

    pub fn set_background_color(&self, color: UIColor) {
        unsafe { msg_send![self.0, setBackgroundColor:color.0] }
    }

    pub fn add_subview(&self, subview: UIView) {
        unsafe { msg_send![self.0, addSubview:subview.0] }
    }
}

// UIViewController
pub struct UIViewController(pub Object);

// UIWindow
#[repr(i32)]
pub enum UIUserInterfaceStyle {
    Dark = 2,
}

pub struct UIWindow(Object);

impl UIWindow {
    pub fn new() -> Self {
        unsafe {
            let window: Object = msg_send![class!(UIWindow), alloc];
            msg_send![window, initWithFrame:UIScreen::main_screen().bounds()]
        }
    }

    pub fn set_override_user_interface_style(&self, style: UIUserInterfaceStyle) {
        unsafe { msg_send![self.0, setOverrideUserInterfaceStyle:style] }
    }

    pub fn set_root_view_controller(&self, uiviewcontroller: UIViewController) {
        unsafe { msg_send![self.0, setRootViewController:uiviewcontroller.0] }
    }

    pub fn make_key_and_visible(&self) {
        unsafe { msg_send![self.0, makeKeyAndVisible] }
    }
}

// UILabel
pub struct UILabel(pub Object);

impl UILabel {
    pub fn new() -> Self {
        unsafe {
            let label: Object = msg_send![class!(UILabel), alloc];
            msg_send![label, init]
        }
    }

    pub fn as_view(&self) -> UIView {
        UIView(self.0)
    }

    pub fn set_text(&self, text: &str) {
        unsafe { msg_send![self.0, setText:NSString::from_str(text).0] }
    }

    pub fn set_font(&self, font: UIFont) {
        unsafe { msg_send![self.0, setFont:font.0] }
    }

    pub fn set_text_alignment(&self, alignment: NSTextAlignment) {
        unsafe { msg_send![self.0, setTextAlignment:alignment] }
    }
}
