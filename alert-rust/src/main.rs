#![no_main]

use crate::cocoa::NSAlert;

mod cocoa;

#[no_mangle]
pub extern "C" fn main() {
    let alert = NSAlert::new();
    alert.set_message_text("Hello Cocoa from Rust!");
    alert.set_informative_text("Rust is quite a nice language to build macOS applications in!");
    alert.run_modal();
}
