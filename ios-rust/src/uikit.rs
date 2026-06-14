use std::ffi::{c_char, c_void};

use objc2::runtime::{AnyObject as Object, NSObject};
use objc2::{extern_class, Encode, Encoding};

#[repr(C)]
pub(crate) struct CGPoint {
    pub x: f64,
    pub y: f64,
}
unsafe impl Encode for CGPoint {
    const ENCODING: Encoding = Encoding::Struct("CGPoint", &[f64::ENCODING, f64::ENCODING]);
}

#[repr(C)]
pub(crate) struct CGSize {
    pub width: f64,
    pub height: f64,
}
unsafe impl Encode for CGSize {
    const ENCODING: Encoding = Encoding::Struct("CGSize", &[f64::ENCODING, f64::ENCODING]);
}

#[repr(C)]
pub(crate) struct CGRect {
    pub origin: CGPoint,
    pub size: CGSize,
}
unsafe impl Encode for CGRect {
    const ENCODING: Encoding = Encoding::Struct("CGRect", &[CGPoint::ENCODING, CGSize::ENCODING]);
}
pub(crate) type NSRect = CGRect;

pub(crate) const UI_USER_INTERFACE_STYLE_DARK: i64 = 2;

pub(crate) const NSTEXT_ALIGNMENT_CENTER: i64 = 1;

#[link(name = "Foundation", kind = "framework")]
extern "C" {
    pub(crate) static __CFConstantStringClassReference: Object;
    pub(crate) fn NSLog(format: *mut Object, ...);
}

#[link(name = "UIKit", kind = "framework")]
extern "C" {
    pub(crate) fn UIApplicationMain(
        argc: i32,
        argv: *const *mut c_char,
        principalClassName: *const Object,
        delegateClassName: *mut Object,
    );
}

extern_class!(
    #[unsafe(super(NSObject))]
    pub(crate) struct UIResponder;
);
extern_class!(
    #[unsafe(super(UIResponder))]
    pub(crate) struct UIViewController;
);

// CFConstString mirrors the layout of Apple's __CFConstantString (CFRuntimeBase + data + len).
// Statics of this type placed in __DATA,__cfstring are recognised by dyld as NSString literals,
// equivalent to Clang's @"..." syntax. The ISA is fixed up at load time via
// __CFConstantStringClassReference (provided by CoreFoundation, transitively linked via Cocoa).
// cfinfo 0x07C8 = ASCII, immutable, not inline, not freed, has NUL terminator.
#[repr(C)]
pub(crate) struct CFConstString {
    pub(crate) isa: *const c_void,
    pub(crate) cfinfo: u32,
    #[cfg(target_pointer_width = "64")]
    pub(crate) _rc: u32,
    pub(crate) data: *const u8,
    pub(crate) len: usize,
}
unsafe impl Send for CFConstString {}
unsafe impl Sync for CFConstString {}

// Creates a zero-cost NSString literal equivalent to Clang's @"..." syntax.
// The string must be ASCII with no interior NUL bytes; this is checked at compile time.
// Returns *mut Object pointing to a static CFConstString in __DATA,__cfstring.
// NOTE: Do not call inside closures - rustc may split the static definition into a
// separate CGU with internal linkage, making it invisible to the linker. Hoist the
// call to the enclosing function scope instead (known rustc bug: madsmtm/objc2#258).
macro_rules! ns_string {
    ($s:expr) => {{
        const INPUT: &str = $s;
        const BYTES: &[u8] = INPUT.as_bytes();
        const _: () = {
            let mut i = 0usize;
            while i < BYTES.len() {
                if !BYTES[i].is_ascii() || BYTES[i] == b'\0' {
                    panic!("ns_string! only supports ASCII strings without NUL bytes");
                }
                i += 1;
            }
        };
        #[link_section = "__TEXT,__cstring,cstring_literals"]
        static DATA: [u8; BYTES.len() + 1] = {
            let mut arr = [0u8; BYTES.len() + 1];
            let mut i = 0usize;
            while i < BYTES.len() {
                arr[i] = BYTES[i];
                i += 1;
            }
            arr
        };
        #[link_section = "__DATA,__cfstring"]
        static CFSTRING: CFConstString = unsafe {
            CFConstString {
                isa: &__CFConstantStringClassReference as *const Object
                    as *const ::std::ffi::c_void,
                cfinfo: 0x07C8,
                #[cfg(target_pointer_width = "64")]
                _rc: 0,
                data: DATA.as_ptr(),
                len: BYTES.len(),
            }
        };
        &CFSTRING as *const CFConstString as *mut objc2::runtime::AnyObject
    }};
}
pub(crate) use ns_string;
