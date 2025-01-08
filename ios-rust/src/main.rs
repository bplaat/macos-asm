#![no_main]

use std::env;
use std::ffi::{c_char, c_void, CString};
use std::ptr::{null, null_mut};

use objc::*;

// MARK: UIKit headers
#[repr(C)]
struct NSRect {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
}

const NS_UTF8_STRING_ENCODING: i32 = 4;
fn ns_string(str: impl AsRef<str>) -> Object {
    unsafe {
        let ns_string: Object = msg_send![msg_send![class!(NSString), alloc], initWithBytes:str.as_ref().as_ptr() length:str.as_ref().len() encoding:NS_UTF8_STRING_ENCODING];
        msg_send![ns_string, autorelease]
    }
}

const UI_USER_INTERFACE_STYLE_DARK: i32 = 2;

const NSTEXT_ALIGNMENT_CENTER: i32 = 1;

extern "C" {
    fn NSLog(format: Object);
    fn UIApplicationMain(
        argc: i32,
        argv: *const *mut c_char,
        principalClassName: Object,
        delegateClassName: Object,
    );
}

// MARK: ViewController
extern "C" fn view_controller_view_did_load(this: Object, _: Sel) {
    unsafe {
        objc_msgSendSuper(
            &Super {
                receiver: this,
                superclass: class!(UIViewController),
            },
            sel!(viewDidLoad),
        );

        let view: Object = msg_send![this, view];

        let background_color: Object = msg_send![class!(UIColor), colorWithRed:(0x05 as f64) / 255.0 green:(0x44 as f64) / 255.0 blue:(0x5e as f64) / 255.0 alpha:1.0];
        let _: () = msg_send![view, setBackgroundColor:background_color];

        let label: Object = msg_send![class!(UILabel), new];
        object_setInstanceVariable(this, c"_label".as_ptr(), label);

        let _: () = msg_send![label, setText:ns_string("Hello iOS!")];
        let font: Object = msg_send![class!(UIFont), systemFontOfSize:48.0];
        let _: () = msg_send![label, setFont:font];
        let _: () = msg_send![label, setTextAlignment:NSTEXT_ALIGNMENT_CENTER];
        let _: () = msg_send![view, addSubview:label];
    }
}

extern "C" fn view_controller_view_will_layout_subviews(this: Object, _: Sel) {
    unsafe {
        objc_msgSendSuper(
            &Super {
                receiver: this,
                superclass: class!(UIViewController),
            },
            sel!(viewWillLayoutSubviews),
        );

        let mut label: Object = null_mut();
        object_getInstanceVariable(this, c"_label".as_ptr(), &mut label);
        let bounds: NSRect = msg_send![msg_send![this, view], bounds];
        let _: () = msg_send![label, setFrame:bounds];
    }
}

// MARK: AppDelegate
extern "C" fn app_delegate_application_did_finish_launching_with_options(
    _: Object,
    _: Sel,
    _: Object,
    _: Object,
) -> bool {
    unsafe {
        let main_screen_bounds: NSRect = msg_send![msg_send![class!(UIScreen), mainScreen], bounds];
        let window: Object =
            msg_send![msg_send![class!(UIWindow), alloc], initWithFrame:main_screen_bounds];
        let _: () = msg_send![window, setOverrideUserInterfaceStyle:UI_USER_INTERFACE_STYLE_DARK];
        let view_controller: Object = msg_send![class!(ViewController), new];
        let _: () = msg_send![window, setRootViewController:view_controller];
        let _: () = msg_send![window, makeKeyAndVisible];

        NSLog(ns_string("Hello iOS!"));
    }
    true
}

// MARK: Main
#[no_mangle]
pub extern "C" fn main() {
    // Register classes
    let mut decl = ClassDecl::new("ViewController", class!(UIViewController)).unwrap();
    decl.add_ivar::<Object>("_label", "^v");
    decl.add_method(
        sel!(viewDidLoad),
        view_controller_view_did_load as *const c_void,
        "v@:",
    );
    decl.add_method(
        sel!(viewWillLayoutSubviews),
        view_controller_view_will_layout_subviews as *const c_void,
        "v@:",
    );
    decl.register();

    let mut decl = ClassDecl::new("AppDelegate", class!(NSObject)).unwrap();
    decl.add_method(
        sel!(application:didFinishLaunchingWithOptions:),
        app_delegate_application_did_finish_launching_with_options as *const c_void,
        "v@:",
    );
    decl.register();

    // Start application
    let argc = env::args().count() as i32;
    let argv = env::args()
        .map(|arg| CString::new(arg).unwrap().into_raw())
        .collect::<Vec<*mut c_char>>();
    unsafe {
        UIApplicationMain(argc, argv.as_ptr(), null(), ns_string("AppDelegate"));
    }
}
