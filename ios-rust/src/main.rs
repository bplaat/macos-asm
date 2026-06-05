#![no_main]

use std::cell::Cell;
use std::env;
use std::ffi::{c_char, c_void, CString};
use std::ptr::null;

use objc2::rc::{autoreleasepool, Retained};
use objc2::runtime::{AnyObject as Object, Bool, NSObject};
use objc2::{
    class, define_class, extern_class, msg_send, ClassType, DefinedClass, Encode, Encoding,
};

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

extern_class!(
    #[unsafe(super(NSObject))]
    struct UIResponder;
);
extern_class!(
    #[unsafe(super(UIResponder))]
    struct UIViewController;
);

// MARK: ViewController
#[derive(Default)]
struct ViewControllerIvars {
    label: Cell<*mut Object>,
}

define_class!(
    #[unsafe(super(UIViewController))]
    #[name = "ViewController"]
    #[ivars = ViewControllerIvars]
    struct ViewController;

    impl ViewController {
        #[unsafe(method(viewDidLoad))]
        fn view_did_load(&self) {
            unsafe {
                let _: () = msg_send![super(self), viewDidLoad];
                let view: *mut Object = msg_send![self, view];

                let background_color: *mut Object = msg_send![class!(UIColor), colorWithRed:(0x05 as f64) / 255.0, green:(0x44 as f64) / 255.0, blue:(0x5e as f64) / 255.0, alpha:1.0];
                let _: () = msg_send![view, setBackgroundColor:background_color];

                let label: *mut Object = msg_send![class!(UILabel), new];
                let _: () = msg_send![label, setText:ns_string("Hello iOS!")];
                let font: *mut Object = msg_send![class!(UIFont), systemFontOfSize:48.0];
                let _: () = msg_send![label, setFont:font];
                let _: () = msg_send![label, setTextAlignment:NSTEXT_ALIGNMENT_CENTER];
                let _: () = msg_send![view, addSubview:label];
                self.ivars().label.set(label);
            }
        }

        #[unsafe(method(viewWillLayoutSubviews))]
        fn view_will_layout_subviews(&self) {
            unsafe {
                let _: () = msg_send![super(self), viewWillLayoutSubviews];
                let view: *mut Object = msg_send![self, view];
                let bounds: NSRect = msg_send![view, bounds];
                let label = self.ivars().label.get();
                if !label.is_null() {
                    let _: () = msg_send![label, setFrame:bounds];
                }
            }
        }
    }
);

// MARK: AppDelegate
define_class!(
    #[unsafe(super(NSObject))]
    #[name = "AppDelegate"]
    struct AppDelegate;

    impl AppDelegate {
        #[unsafe(method(application:didFinishLaunchingWithOptions:))]
        fn application_did_finish_launching(
            &self,
            _app: *const Object,
            _options: *const Object,
        ) -> Bool {
            unsafe {
                let main_screen: *mut Object = msg_send![class!(UIScreen), mainScreen];
                let main_screen_bounds: NSRect = msg_send![main_screen, bounds];
                let window: *mut Object = msg_send![class!(UIWindow), alloc];
                let window: *mut Object = msg_send![window, initWithFrame:main_screen_bounds];
                let _: () = msg_send![window, setOverrideUserInterfaceStyle:UI_USER_INTERFACE_STYLE_DARK];
                let view_controller: Retained<Object> = msg_send![class!(ViewController), new];
                let _: () = msg_send![window, setRootViewController:&*view_controller];
                let _: () = msg_send![window, makeKeyAndVisible];

                NSLog(ns_string("Hello iOS!"));
            }
            Bool::YES
        }
    }
);

// MARK: Main
#[no_mangle]
pub extern "C" fn main() {
    // Register classes
    let _ = ViewController::class();
    let _ = AppDelegate::class();

    // Start application
    autoreleasepool(|_| {
        let argc = env::args().count() as i32;
        let argv: Vec<*mut c_char> = env::args()
            .map(|arg| CString::new(arg).unwrap().into_raw())
            .collect();
        unsafe { UIApplicationMain(argc, argv.as_ptr(), null(), ns_string("AppDelegate")) };
    });
}
