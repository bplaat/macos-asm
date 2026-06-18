use std::cell::Cell;
use std::env;
use std::ffi::{c_char, CString};
use std::ptr::null;

use objc2::rc::autoreleasepool;
use objc2::runtime::{AnyObject as Object, Bool, NSObject};
use objc2::{class, define_class, msg_send, ClassType, DefinedClass};

use crate::uikit::*;

mod uikit;

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
        fn _view_did_load(&self) { self.view_did_load(); }

        #[unsafe(method(viewWillLayoutSubviews))]
        fn _view_will_layout_subviews(&self) { self.view_will_layout_subviews(); }
    }
);

impl ViewController {
    fn view_did_load(&self) {
        unsafe {
            let _: () = msg_send![super(self), viewDidLoad];
            let view: *mut Object = msg_send![self, view];

            let background_color: *mut Object = msg_send![class!(UIColor), colorWithRed:(0x05 as f64) / 255.0, green:(0x44 as f64) / 255.0, blue:(0x5e as f64) / 255.0, alpha:1.0];
            let _: () = msg_send![view, setBackgroundColor:background_color];

            let label: *mut Object = msg_send![class!(UILabel), new];
            let _: () = msg_send![label, setText:ns_string!("Hello iOS!")];
            let font: *mut Object = msg_send![class!(UIFont), systemFontOfSize:48.0];
            let _: () = msg_send![label, setFont:font];
            let _: () = msg_send![label, setTextAlignment:NSTEXT_ALIGNMENT_CENTER];
            let _: () = msg_send![view, addSubview:label];
            self.ivars().label.set(label);
        }
    }

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

// MARK: AppDelegate
#[derive(Default)]
struct AppDelegateIvars {
    window: Cell<*mut Object>,
}

define_class!(
    #[unsafe(super(NSObject))]
    #[name = "AppDelegate"]
    #[ivars = AppDelegateIvars]
    struct AppDelegate;

    impl AppDelegate {
        #[unsafe(method(application:didFinishLaunchingWithOptions:))]
        fn _application_did_finish_launching(&self, app: *const Object, options: *const Object) -> Bool {
            self.application_did_finish_launching(app, options)
        }
    }
);

impl AppDelegate {
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
            let _: () =
                msg_send![window, setOverrideUserInterfaceStyle:UI_USER_INTERFACE_STYLE_DARK];
            let view_controller: *mut Object = msg_send![class!(ViewController), new];
            let _: () = msg_send![window, setRootViewController:view_controller];
            let _: () = msg_send![window, makeKeyAndVisible];
            self.ivars().window.set(window);

            NSLog(ns_string!("Hello iOS!"));
        }
        Bool::YES
    }
}

// MARK: Main
fn main() {
    // Register classes
    let _ = ViewController::class();
    let _ = AppDelegate::class();

    // Start application
    let app_delegate_name = ns_string!("AppDelegate");
    autoreleasepool(|_| {
        let argc = env::args().count() as i32;
        let argv: Vec<*mut c_char> = env::args()
            .map(|arg| CString::new(arg).unwrap().into_raw())
            .collect();
        unsafe { UIApplicationMain(argc, argv.as_ptr(), null(), app_delegate_name) };
    });
}
