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
            $crate::objc::objc_getClass(name.as_ptr() as *const std::ffi::c_char)
        }
    }};
}

#[macro_export]
macro_rules! sel {
    ($name:ident) => {{
        #[allow(unused_unsafe)]
        unsafe {
            let name = concat!(stringify!($name), '\0');
            $crate::objc::sel_registerName(name.as_ptr() as *const std::ffi::c_char)
        }
    }};
    ($($name:ident :)+) => ({
        #[allow(unused_unsafe)]
        unsafe {
            let name = concat!($(stringify!($name), ':'),+, '\0');
            $crate::objc::sel_registerName(name.as_ptr() as *const std::ffi::c_char)
        }
    });
}

pub trait MessageSend {
    unsafe fn invoke<R>(obj: Object, sel: Sel, args: Self) -> R;
}
macro_rules! message_send_impl {
    ($($a:ident : $t:ident),*) => (
        impl<$($t),*> MessageSend for ($($t,)*) {
            #[inline(always)]
            unsafe fn invoke<R>(obj: Object, sel: Sel, ($($a,)*): Self) -> R {
                let imp: unsafe extern fn (Object, Sel, $($t,)*) -> R =
                    std::mem::transmute(objc_msgSend as *const c_void);
                imp(obj, sel, $($a,)*)
            }
        }
    );
}
message_send_impl!();
message_send_impl!(a: A);
message_send_impl!(a: A, b: B);
message_send_impl!(a: A, b: B, c: C);
message_send_impl!(a: A, b: B, c: C, d: D);
message_send_impl!(a: A, b: B, c: C, d: D, e: E);
message_send_impl!(a: A, b: B, c: C, d: D, e: E, f: F);

#[macro_export]
macro_rules! msg_send {
    ($receiver:expr, $sel:ident) => (
        $crate::objc::MessageSend::invoke($receiver, $crate::sel!($sel), ())
    );
    ($receiver:expr, $($sel:ident : $arg:expr)+) => (
        $crate::objc::MessageSend::invoke($receiver, $crate::sel!($($sel:)+), ($($arg,)+))
    );
}
