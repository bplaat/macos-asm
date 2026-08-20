use std::cell::{OnceCell, RefCell};
use std::env;
use std::ffi::{c_char, CString};
use std::ptr::null_mut;

use objc2::rc::{autoreleasepool, Allocated, Retained};
use objc2::runtime::{AnyObject as Object, Bool, NSObject};
use objc2::{class, define_class, msg_send, ClassType, DefinedClass};

use crate::uikit::{
    ns_string, NSLog, NSRect, UIApplicationMain, UIViewController, NSTEXT_ALIGNMENT_CENTER,
    UI_USER_INTERFACE_STYLE_DARK,
};

mod uikit;

// MARK: ViewController
#[derive(Default)]
struct ViewControllerIvars {
    label: RefCell<Option<Retained<Object>>>,
}

define_class!(
    #[unsafe(super(UIViewController))]
    #[name = "ViewController"]
    #[ivars = ViewControllerIvars]
    struct ViewController;

    impl ViewController {
        #[unsafe(method_id(init))]
        fn _init(this: Allocated<Self>) -> Option<Retained<Self>> {
            unsafe { msg_send![super(this.set_ivars(ViewControllerIvars::default())), init] }
        }

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
            let view: Retained<Object> = msg_send![self, view];

            let background_color: Retained<Object> = msg_send![class!(UIColor), colorWithRed:(0x05 as f64) / 255.0, green:(0x44 as f64) / 255.0, blue:(0x5e as f64) / 255.0, alpha:1.0];
            let _: () = msg_send![&view, setBackgroundColor:&*background_color];

            let label: Retained<Object> = msg_send![class!(UILabel), new];
            let _: () = msg_send![&label, setText:ns_string!("Hello iOS!")];
            let font: Retained<Object> = msg_send![class!(UIFont), systemFontOfSize:48.0];
            let _: () = msg_send![&label, setFont:&*font];
            let _: () = msg_send![&label, setTextAlignment:NSTEXT_ALIGNMENT_CENTER];
            let _: () = msg_send![&view, addSubview:&*label];
            self.ivars().label.replace(Some(label));
        }
    }

    fn view_will_layout_subviews(&self) {
        unsafe {
            let _: () = msg_send![super(self), viewWillLayoutSubviews];
            let view: Retained<Object> = msg_send![self, view];
            let bounds: NSRect = msg_send![&view, bounds];
            let label = self.ivars().label.borrow().clone();
            if let Some(label) = label {
                let _: () = msg_send![&label, setFrame:bounds];
            }
        }
    }
}

// MARK: AppDelegate
#[derive(Default)]
struct AppDelegateIvars {
    window: OnceCell<Retained<Object>>,
}

define_class!(
    #[unsafe(super(NSObject))]
    #[name = "AppDelegate"]
    #[ivars = AppDelegateIvars]
    struct AppDelegate;

    impl AppDelegate {
        #[unsafe(method_id(init))]
        fn _init(this: Allocated<Self>) -> Option<Retained<Self>> {
            unsafe { msg_send![super(this.set_ivars(AppDelegateIvars::default())), init] }
        }

        #[unsafe(method(application:didFinishLaunchingWithOptions:))]
        fn _application_did_finish_launching(&self, app: &Object, options: Option<&Object>) -> Bool {
            self.application_did_finish_launching(app, options)
        }
    }
);

impl AppDelegate {
    fn application_did_finish_launching(&self, _app: &Object, _options: Option<&Object>) -> Bool {
        unsafe {
            let main_screen: Retained<Object> = msg_send![class!(UIScreen), mainScreen];
            let main_screen_bounds: NSRect = msg_send![&main_screen, bounds];
            let window: Allocated<Object> = msg_send![class!(UIWindow), alloc];
            let window: Retained<Object> = msg_send![window, initWithFrame:main_screen_bounds];
            let _: () =
                msg_send![&window, setOverrideUserInterfaceStyle:UI_USER_INTERFACE_STYLE_DARK];
            let view_controller: Retained<ViewController> = msg_send![class!(ViewController), new];
            let _: () = msg_send![&window, setRootViewController:&*view_controller];
            let _: () = msg_send![&window, makeKeyAndVisible];
            if self.ivars().window.set(window).is_err() {
                eprintln!("Application delegate was already initialized");
                return Bool::NO;
            }

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
        let mut args: Vec<Vec<u8>> = env::args()
            .map(|arg| CString::new(arg).expect("application arguments cannot contain NUL bytes"))
            .map(CString::into_bytes_with_nul)
            .collect();
        let argc = i32::try_from(args.len()).expect("too many application arguments");
        let mut argv: Vec<*mut c_char> = args
            .iter_mut()
            .map(|arg| arg.as_mut_ptr().cast::<c_char>())
            .collect();
        argv.push(null_mut());
        let _ =
            unsafe { UIApplicationMain(argc, argv.as_mut_ptr(), null_mut(), app_delegate_name) };
    });
}
