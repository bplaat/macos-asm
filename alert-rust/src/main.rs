#![no_main]

use objc::*;

// NSString
const NS_UTF8_STRING_ENCODING: i32 = 4;
fn ns_string(str: impl AsRef<str>) -> Object {
    unsafe {
        let ns_string: Object = msg_send![msg_send![class!(NSString), alloc], initWithBytes:str.as_ref().as_ptr() length:str.as_ref().len() encoding:NS_UTF8_STRING_ENCODING];
        msg_send![ns_string, autorelease]
    }
}

#[no_mangle]
pub extern "C" fn main() {
    unsafe {
        let alert: Object = msg_send![class!(NSAlert), new];
        let _: () = msg_send![alert, setMessageText:ns_string("Hello Cocoa from Rust!")];
        let _: () = msg_send![alert, setInformativeText:ns_string("Rust is quite a nice language to build macOS applications in!")];
        let _: () = msg_send![alert, runModal];
    }
}
