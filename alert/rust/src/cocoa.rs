use std::ffi::c_void;

use objc2::runtime::AnyObject as Object;

#[link(name = "Foundation", kind = "framework")]
extern "C" {
    pub(crate) static __CFConstantStringClassReference: Object;
}

#[link(name = "Cocoa", kind = "framework")]
extern "C" {}

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
        static CFSTRING: $crate::cocoa::CFConstString = unsafe {
            $crate::cocoa::CFConstString {
                isa: &$crate::cocoa::__CFConstantStringClassReference
                    as *const objc2::runtime::AnyObject
                    as *const ::std::ffi::c_void,
                cfinfo: 0x07C8,
                #[cfg(target_pointer_width = "64")]
                _rc: 0,
                data: DATA.as_ptr(),
                len: BYTES.len(),
            }
        };
        &CFSTRING as *const $crate::cocoa::CFConstString as *mut objc2::runtime::AnyObject
    }};
}
pub(crate) use ns_string;
