use std::ffi::{c_char, c_void};

pub type Class = *const c_void;
pub type Sel = *const c_void;
pub type Object = *const c_void;

#[link(name = "objc", kind = "dylib")]
extern "C" {
    pub fn objc_getClass(name: *const c_char) -> Class;
    pub fn sel_registerName(name: *const c_char) -> Sel;
    pub fn objc_msgSend(receiver: Object, sel: Sel, ...) -> *const c_void;
}

#[macro_export]
macro_rules! class {
    ($name:ident) => {{
        #[allow(unused_unsafe)]
        unsafe {
            let name = concat!(stringify!($name), '\0');
            crate::objc::objc_getClass(name.as_ptr() as *const std::ffi::c_char)
        }
    }};
}
#[macro_export]
macro_rules! sel {
    ($name:ident) => {{
        #[allow(unused_unsafe)]
        unsafe {
            let name = concat!(stringify!($name), '\0');
            crate::objc::sel_registerName(name.as_ptr() as *const std::ffi::c_char)
        }
    }};
    ($($name:ident :)+) => ({
        #[allow(unused_unsafe)]
        unsafe {
            let name = concat!($(stringify!($name), ':'),+, '\0');
            crate::objc::sel_registerName(name.as_ptr() as *const std::ffi::c_char)
        }
    });
}
#[macro_export]
macro_rules! msg_send {
    ($receiver:expr, $sel:ident) => {{
        let msg_send : extern "C" fn (receiver: Object, sel: crate::objc::Sel) -> _ =
        std::mem::transmute(crate::objc::objc_msgSend as *const std::ffi::c_void);
        msg_send(std::mem::transmute($receiver), $crate::sel!($sel))
    }};
    // FIXME: This is dump but I don't know how to expand _'s in func type decl
    ($receiver:expr, $sel1:ident : $arg1:expr) => ({
        let msg_send : extern "C" fn (receiver: Object, sel: crate::objc::Sel, _) -> _ =
        std::mem::transmute(crate::objc::objc_msgSend as *const std::ffi::c_void);
        msg_send(std::mem::transmute($receiver), $crate::sel!($sel1:), $arg1)
    });
    ($receiver:expr, $sel1:ident : $arg1:expr, $sel2:ident : $arg2:expr) => ({
        let msg_send : extern "C" fn (receiver: Object, sel: crate::objc::Sel, _, _) -> _ =
        std::mem::transmute(crate::objc::objc_msgSend as *const std::ffi::c_void);
        msg_send(std::mem::transmute($receiver), $crate::sel!($sel1:$sel2:), $arg1, $arg2)
    });
    ($receiver:expr, $sel1:ident : $arg1:expr, $sel2:ident : $arg2:expr, $sel3:ident : $arg3:expr) => ({
        let msg_send : extern "C" fn (receiver: Object, sel: crate::objc::Sel, _, _, _) -> _ =
        std::mem::transmute(crate::objc::objc_msgSend as *const std::ffi::c_void);
        msg_send(std::mem::transmute($receiver), $crate::sel!($sel1:$sel2:$sel3:), $arg1, $arg2, $arg3)
    });
}
