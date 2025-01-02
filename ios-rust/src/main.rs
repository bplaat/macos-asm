#![no_main]

use std::ffi::c_void;
use std::ffi::CStr;
use std::ptr::null;

use objc::*;

use crate::uikit::*;

mod uikit;

pub const VIEW_IVAR: &CStr = c"_view";
pub const LABEL_STR: &str = "label";
pub const LABEL_IVAR: &CStr = c"_label";

extern "C" fn view_did_load(this: Object, _: Sel) {
    unsafe {
        objc_msgSendSuper(
            &Super {
                receiver: this,
                superclass: class!(UIViewController),
            },
            sel!(viewDidLoad),
        );
    }

    let mut view = UIView(null());
    unsafe {
        object_getInstanceVariable(this, VIEW_IVAR.as_ptr(), &mut view.0);
    };
    view.set_background_color(UIColor::from_rgba(0x05, 0x44, 0x5e, 0xff));

    let label = UILabel::new();
    unsafe {
        object_setInstanceVariable(this, LABEL_IVAR.as_ptr(), label.0);
    }
    label.set_text("Hello iOS!");
    label.set_font(UIFont::system_font_of_size(48.0));
    label.set_text_alignment(NSTextAlignment::Center);
    view.add_subview(label.as_view());
}

extern "C" fn view_will_layout_subviews(this: Object, _: Sel) {
    unsafe {
        objc_msgSendSuper(
            &Super {
                receiver: this,
                superclass: class!(UIViewController),
            },
            sel!(viewWillLayoutSubviews),
        );
    }

    let mut view = UIView(null());
    let mut label = UILabel(null());
    unsafe {
        object_getInstanceVariable(this, VIEW_IVAR.as_ptr(), &mut view.0);
        object_getInstanceVariable(this, LABEL_IVAR.as_ptr(), &mut label.0);
    };
    label.as_view().set_frame(view.bounds());
}

extern "C" fn application(_: Object, _: Sel, _: Object, _: Object) -> bool {
    let window = UIWindow::new();
    window.set_override_user_interface_style(UIUserInterfaceStyle::Dark);
    window.set_root_view_controller(UIViewController(unsafe {
        msg_send![class!(ViewController), new]
    }));
    window.make_key_and_visible();

    unsafe { NSLog(NSString::from_str("Hello iOS!").0) };
    true
}

#[no_mangle]
pub extern "C" fn main() {
    // ViewController
    let mut class = ClassDecl::new("ViewController", class!(UIViewController)).unwrap();
    class.add_ivar::<*const c_void>(LABEL_STR, "^v");
    class.add_method(sel!(viewDidLoad), view_did_load as *const c_void, "v@:");
    class.add_method(
        sel!(viewWillLayoutSubviews),
        view_will_layout_subviews as *const c_void,
        "v@:",
    );
    class.register();

    // AppDelegate
    let mut class = ClassDecl::new("AppDelegate", class!(NSObject)).unwrap();
    class.add_method(
        sel!(application:didFinishLaunchingWithOptions:),
        application as *const c_void,
        "v@:",
    );
    class.register();

    ui_application_main("AppDelegate");
}
