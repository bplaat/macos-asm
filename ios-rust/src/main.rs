#![no_main]

use std::env;
use std::ffi::{c_char, c_void, CString};
use std::ptr::null;

use objc2::runtime::{AnyObject as Object, Bool, ClassBuilder, Sel};
use objc2::{class, msg_send, sel, Encode, Encoding};

// MARK: UIKit headers
#[repr(C)]
struct CGPoint {
    x: f64,
    y: f64,
}
unsafe impl Encode for CGPoint {
    const ENCODING: Encoding = Encoding::Struct("CGPoint", &[f64::ENCODING, f64::ENCODING]);
}

#[repr(C)]
struct CGSize {
    width: f64,
    height: f64,
}
unsafe impl Encode for CGSize {
    const ENCODING: Encoding = Encoding::Struct("CGSize", &[f64::ENCODING, f64::ENCODING]);
}

#[repr(C)]
struct CGRect {
    origin: CGPoint,
    size: CGSize,
}
unsafe impl Encode for CGRect {
    const ENCODING: Encoding = Encoding::Struct("CGRect", &[CGPoint::ENCODING, CGSize::ENCODING]);
}
type NSRect = CGRect;

const NS_UTF8_STRING_ENCODING: u64 = 4;
fn ns_string(str: impl AsRef<str>) -> *mut Object {
    let str = str.as_ref();
    unsafe {
        let ns_string: *mut Object = msg_send![class!(NSString), alloc];
        let ns_string: *mut Object = msg_send![ns_string, initWithBytes:str.as_ptr().cast::<c_void>(), length:str.len(), encoding:NS_UTF8_STRING_ENCODING];
        msg_send![ns_string, autorelease]
    }
}
const UI_USER_INTERFACE_STYLE_DARK: i64 = 2;

const NSTEXT_ALIGNMENT_CENTER: i64 = 1;

extern "C" {
    fn NSLog(format: *mut Object, ...);
    fn UIApplicationMain(
        argc: i32,
        argv: *const *mut c_char,
        principalClassName: *const Object,
        delegateClassName: *mut Object,
    );
}

// MARK: ViewController
const IVAR_LABEL: &str = "_label";

extern "C" fn view_controller_view_did_load(this: *mut Object, _: Sel) {
    unsafe {
        let _: () = msg_send![super(this, class!(UIViewController)), viewDidLoad];

        let view: *mut Object = msg_send![this, view];

        let background_color: *mut Object = msg_send![class!(UIColor), colorWithRed:(0x05 as f64) / 255.0, green:(0x44 as f64) / 255.0, blue:(0x5e as f64) / 255.0, alpha:1.0];
        let _: () = msg_send![view, setBackgroundColor:background_color];

        let label: *mut Object = msg_send![class!(UILabel), new];
        let _: () = msg_send![label, setText:ns_string("Hello iOS!")];
        let font: *mut Object = msg_send![class!(UIFont), systemFontOfSize:48.0];
        let _: () = msg_send![label, setFont:font];
        let _: () = msg_send![label, setTextAlignment:NSTEXT_ALIGNMENT_CENTER];
        let _: () = msg_send![view, addSubview:label];

        #[allow(deprecated)]
        let label_ptr: &mut *mut Object = (*this).get_mut_ivar::<*mut Object>(IVAR_LABEL);
        *label_ptr = label;
    }
}

extern "C" fn view_controller_view_will_layout_subviews(this: *mut Object, _: Sel) {
    unsafe {
        let _: () = msg_send![
            super(this, class!(UIViewController)),
            viewWillLayoutSubviews
        ];

        let view: *mut Object = msg_send![this, view];
        let bounds: NSRect = msg_send![view, bounds];
        #[allow(deprecated)]
        let label = *(*this).get_ivar::<*mut Object>(IVAR_LABEL);
        let _: () = msg_send![label, setFrame:bounds];
    }
}

// MARK: AppDelegate
extern "C" fn app_delegate_application_did_finish_launching_with_options(
    _: *mut Object,
    _: Sel,
    _: *const Object,
    _: *const Object,
) -> Bool {
    unsafe {
        let main_screen: *mut Object = msg_send![class!(UIScreen), mainScreen];
        let main_screen_bounds: NSRect = msg_send![main_screen, bounds];
        let window: *mut Object = msg_send![class!(UIWindow), alloc];
        let window: *mut Object = msg_send![window, initWithFrame:main_screen_bounds];
        let _: () = msg_send![window, setOverrideUserInterfaceStyle:UI_USER_INTERFACE_STYLE_DARK];
        let view_controller: *mut Object = msg_send![class!(ViewController), new];
        let _: () = msg_send![window, setRootViewController:view_controller];
        let _: () = msg_send![window, makeKeyAndVisible];

        NSLog(ns_string("Hello iOS!"));
    }
    Bool::YES
}

// MARK: Main
#[no_mangle]
pub extern "C" fn main() {
    // Register classes
    let mut decl = ClassBuilder::new(c"ViewController", class!(UIViewController)).unwrap();
    decl.add_ivar::<*const Object>(&CString::new(IVAR_LABEL).unwrap());
    unsafe {
        decl.add_method(
            sel!(viewDidLoad),
            view_controller_view_did_load as extern "C" fn(_, _),
        );
        decl.add_method(
            sel!(viewWillLayoutSubviews),
            view_controller_view_will_layout_subviews as extern "C" fn(_, _),
        );
    }
    decl.register();

    let mut decl = ClassBuilder::new(c"AppDelegate", class!(NSObject)).unwrap();
    unsafe {
        decl.add_method(
            sel!(application:didFinishLaunchingWithOptions:),
            app_delegate_application_did_finish_launching_with_options
                as extern "C" fn(_, _, _, _) -> _,
        );
    }
    decl.register();

    // Start application
    let argc = env::args().count() as i32;
    let argv = env::args()
        .map(|arg| CString::new(arg).unwrap().into_raw())
        .collect::<Vec<*mut c_char>>();
    unsafe { UIApplicationMain(argc, argv.as_ptr(), null(), ns_string("AppDelegate")) };
}
