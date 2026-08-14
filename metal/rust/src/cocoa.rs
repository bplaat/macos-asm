use std::ffi::c_void;

use objc2::runtime::AnyObject as Object;
use objc2::{Encode, Encoding};

#[repr(C)]
#[derive(Clone, Copy)]
pub(crate) struct CGPoint {
    pub(crate) x: f64,
    pub(crate) y: f64,
}

impl CGPoint {
    pub(crate) const fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }
}

unsafe impl Encode for CGPoint {
    const ENCODING: Encoding = Encoding::Struct("CGPoint", &[f64::ENCODING, f64::ENCODING]);
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(crate) struct CGSize {
    pub(crate) width: f64,
    pub(crate) height: f64,
}

impl CGSize {
    pub(crate) const fn new(width: f64, height: f64) -> Self {
        Self { width, height }
    }
}

unsafe impl Encode for CGSize {
    const ENCODING: Encoding = Encoding::Struct("CGSize", &[f64::ENCODING, f64::ENCODING]);
}

#[repr(C)]
#[derive(Clone, Copy)]
pub(crate) struct CGRect {
    pub(crate) origin: CGPoint,
    pub(crate) size: CGSize,
}

impl CGRect {
    pub(crate) const fn new(origin: CGPoint, size: CGSize) -> Self {
        Self { origin, size }
    }
}

unsafe impl Encode for CGRect {
    const ENCODING: Encoding = Encoding::Struct("CGRect", &[CGPoint::ENCODING, CGSize::ENCODING]);
}

pub(crate) type NSPoint = CGPoint;
pub(crate) type NSSize = CGSize;
pub(crate) type NSRect = CGRect;

#[repr(C)]
#[derive(Clone, Copy)]
pub(crate) struct MTLClearColor {
    pub(crate) red: f64,
    pub(crate) green: f64,
    pub(crate) blue: f64,
    pub(crate) alpha: f64,
}

impl MTLClearColor {
    pub(crate) const fn new(red: f64, green: f64, blue: f64, alpha: f64) -> Self {
        Self {
            red,
            green,
            blue,
            alpha,
        }
    }
}

unsafe impl Encode for MTLClearColor {
    const ENCODING: Encoding = Encoding::Struct(
        "?",
        &[f64::ENCODING, f64::ENCODING, f64::ENCODING, f64::ENCODING],
    );
}

pub(crate) const NS_APPLICATION_ACTIVATION_POLICY_REGULAR: isize = 0;
pub(crate) const NS_WINDOW_STYLE_MASK_TITLED: usize = 1;
pub(crate) const NS_WINDOW_STYLE_MASK_CLOSABLE: usize = 2;
pub(crate) const NS_WINDOW_STYLE_MASK_MINIATURIZABLE: usize = 4;
pub(crate) const NS_WINDOW_STYLE_MASK_RESIZABLE: usize = 8;
pub(crate) const NS_VIEW_WIDTH_SIZABLE: usize = 2;
pub(crate) const NS_VIEW_HEIGHT_SIZABLE: usize = 16;
pub(crate) const NS_BACKING_STORE_BUFFERED: usize = 2;
pub(crate) const MTL_PIXEL_FORMAT_BGRA8_UNORM: usize = 80;
pub(crate) const MTL_PRIMITIVE_TYPE_TRIANGLE: usize = 3;

#[link(name = "Foundation", kind = "framework")]
extern "C" {
    pub(crate) static __CFConstantStringClassReference: Object;
}

#[link(name = "Cocoa", kind = "framework")]
extern "C" {
    pub(crate) static NSApp: *mut Object;
    pub(crate) static NSAppearanceNameDarkAqua: *const Object;
}

#[link(name = "Metal", kind = "framework")]
extern "C" {
    pub(crate) fn MTLCreateSystemDefaultDevice() -> *mut Object;
}

#[link(name = "MetalKit", kind = "framework")]
extern "C" {}

#[repr(C)]
pub(crate) struct CFConstString {
    pub(crate) isa: *const c_void,
    pub(crate) cfinfo: u32,
    #[cfg(target_pointer_width = "64")]
    pub(crate) rc: u32,
    pub(crate) data: *const u8,
    pub(crate) len: usize,
}

unsafe impl Send for CFConstString {}
unsafe impl Sync for CFConstString {}

macro_rules! ns_string {
    ($string:expr) => {{
        const STRING: &str = $string;
        const BYTES: &[u8] = STRING.as_bytes();
        const _: () = {
            let mut index = 0;
            while index < BYTES.len() {
                assert!(BYTES[index].is_ascii() && BYTES[index] != b'\0');
                index += 1;
            }
        };

        #[link_section = "__TEXT,__cstring,cstring_literals"]
        static DATA: [u8; BYTES.len() + 1] = {
            let mut data = [0; BYTES.len() + 1];
            let mut index = 0;
            while index < BYTES.len() {
                data[index] = BYTES[index];
                index += 1;
            }
            data
        };

        #[link_section = "__DATA,__cfstring"]
        static CFSTRING: $crate::cocoa::CFConstString = unsafe {
            $crate::cocoa::CFConstString {
                isa: &$crate::cocoa::__CFConstantStringClassReference
                    as *const objc2::runtime::AnyObject
                    as *const std::ffi::c_void,
                cfinfo: 0x07c8,
                #[cfg(target_pointer_width = "64")]
                rc: 0,
                data: DATA.as_ptr(),
                len: BYTES.len(),
            }
        };

        &CFSTRING as *const $crate::cocoa::CFConstString as *mut objc2::runtime::AnyObject
    }};
}

pub(crate) use ns_string;
