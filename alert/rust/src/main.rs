use objc2::rc::{autoreleasepool, Retained};
use objc2::runtime::AnyObject;
use objc2::{class, msg_send};

use crate::cocoa::ns_string;

mod cocoa;

fn main() {
    let message = ns_string!("Hello Cocoa from Rust!");
    autoreleasepool(|_| unsafe {
        let alert: Retained<AnyObject> = msg_send![class!(NSAlert), new];
        let _: () = msg_send![&alert, setMessageText:message];
        let _: isize = msg_send![&alert, runModal];
    });
}
