use objc2::rc::autoreleasepool;
use objc2::runtime::AnyObject;
use objc2::{class, msg_send};

#[link(name = "Cocoa", kind = "framework")]
extern "C" {}

fn main() {
    autoreleasepool(|_| unsafe {
        let alert: *mut AnyObject = msg_send![class!(NSAlert), new];
        let message: *mut AnyObject = msg_send![
            class!(NSString),
            stringWithUTF8String: c"Hello Cocoa from Rust!".as_ptr()
        ];
        let _: () = msg_send![alert, setMessageText: message];
        let _: isize = msg_send![alert, runModal];
    });
}
