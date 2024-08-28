use std::ffi::{c_char, c_void, CString};

pub type Class = *const c_void;
pub type Sel = *const c_void;
pub type Object = *const c_void;

#[link(name = "objc", kind = "dylib")]
extern "C" {
    pub fn objc_getClass(name: *const c_char) -> Class;
    pub fn sel_registerName(name: *const c_char) -> Sel;
    pub fn objc_msgSend(receiver: Object, sel: Sel, ...) -> *const c_void;
    pub fn object_getInstanceVariable(
        obj: Object,
        name: *const c_char,
        outValue: *mut *const c_void,
    ) -> *const c_void;
    pub fn object_setInstanceVariable(
        obj: Object,
        name: *const c_char,
        value: *const c_void,
    ) -> *const c_void;
    pub fn objc_allocateClassPair(
        superclass: Class,
        name: *const c_char,
        extraBytes: usize,
    ) -> Class;
    pub fn class_addIvar(
        class: Class,
        name: *const c_char,
        size: usize,
        alignment: u8,
        types: *const c_char,
    ) -> bool;
    pub fn class_addMethod(
        class: Class,
        sel: Sel,
        imp: *const c_void,
        types: *const c_char,
    ) -> bool;
    pub fn objc_registerClassPair(class: Class);
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
#[macro_export]
macro_rules! msg_send {
    ($receiver:expr, $sel:ident) => {{
        let msg_send : extern "C" fn (receiver: Object, sel: $crate::objc::Sel) -> _ =
        std::mem::transmute($crate::objc::objc_msgSend as *const std::ffi::c_void);
        msg_send($receiver, $crate::sel!($sel))
    }};
    // FIXME: This is dump but I don't know how to expand _'s in func type decl
    ($receiver:expr, $sel1:ident : $arg1:expr) => ({
        let msg_send : extern "C" fn (receiver: Object, sel: $crate::objc::Sel, _) -> _ =
        std::mem::transmute($crate::objc::objc_msgSend as *const std::ffi::c_void);
        msg_send($receiver, $crate::sel!($sel1:), $arg1)
    });
    ($receiver:expr, $sel1:ident : $arg1:expr, $sel2:ident : $arg2:expr) => ({
        let msg_send : extern "C" fn (receiver: Object, sel: $crate::objc::Sel, _, _) -> _ =
        std::mem::transmute($crate::objc::objc_msgSend as *const std::ffi::c_void);
        msg_send($receiver, $crate::sel!($sel1:$sel2:), $arg1, $arg2)
    });
    ($receiver:expr, $sel1:ident : $arg1:expr, $sel2:ident : $arg2:expr, $sel3:ident : $arg3:expr) => ({
        let msg_send : extern "C" fn (receiver: Object, sel: $crate::objc::Sel, _, _, _) -> _ =
        std::mem::transmute($crate::objc::objc_msgSend as *const std::ffi::c_void);
        msg_send($receiver, $crate::sel!($sel1:$sel2:$sel3:), $arg1, $arg2, $arg3)
    });
    ($receiver:expr, $sel1:ident : $arg1:expr, $sel2:ident : $arg2:expr, $sel3:ident : $arg3:expr, $sel4:ident : $arg4:expr) => ({
        let msg_send : extern "C" fn (receiver: Object, sel: $crate::objc::Sel, _, _, _, _) -> _ =
        std::mem::transmute($crate::objc::objc_msgSend as *const std::ffi::c_void);
        msg_send($receiver, $crate::sel!($sel1:$sel2:$sel3:$sel4:), $arg1, $arg2, $arg3, $arg4)
    });
}

#[repr(C)]
pub struct ClassDecl(Class);
impl ClassDecl {
    pub fn new(name: &str, superclass: Class) -> Option<Self> {
        let name = CString::new(name).unwrap();
        let class: Class = unsafe { objc_allocateClassPair(superclass, name.as_ptr(), 0) };
        if class.is_null() {
            None
        } else {
            Some(Self(class))
        }
    }
    pub fn add_ivar<T>(&mut self, name: *const c_char, types: &str) -> bool {
        let types = CString::new(types).unwrap();
        unsafe {
            class_addIvar(
                self.0,
                name,
                std::mem::size_of::<T>(),
                std::mem::align_of::<T>().trailing_zeros() as u8,
                types.as_ptr(),
            )
        }
    }
    pub fn add_method(&mut self, sel: Sel, imp: *const c_void, types: &str) -> bool {
        let types = CString::new(types).unwrap();
        unsafe { class_addMethod(self.0, sel, imp, types.as_ptr()) }
    }
    pub fn register(&mut self) -> Class {
        unsafe { objc_registerClassPair(self.0) }
        self.0
    }
}
