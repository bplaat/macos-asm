use objc::{class, msg_send, Object};

// NSString
pub const NS_UTF8_STRING_ENCODING: i32 = 4;
pub struct NSString(Object);
impl NSString {
    pub fn from_str(str: impl AsRef<str>) -> Self {
        unsafe {
            let ns_string: Object = msg_send![class!(NSString), alloc];
            let ns_string: Object = msg_send![ns_string, initWithBytes:str.as_ref().as_ptr() length:str.as_ref().len() encoding:NS_UTF8_STRING_ENCODING];
            msg_send![ns_string, autorelease]
        }
    }
}

// NSAlert
pub struct NSAlert(Object);
impl NSAlert {
    pub fn new() -> Self {
        unsafe { msg_send![class!(NSAlert), new] }
    }
    pub fn set_message_text(&self, text: impl AsRef<str>) {
        unsafe { msg_send![self.0, setMessageText:NSString::from_str(text).0] }
    }
    pub fn set_informative_text(&self, text: impl AsRef<str>) {
        unsafe { msg_send![self.0, setInformativeText:NSString::from_str(text).0] }
    }
    pub fn run_modal(&self) {
        unsafe { msg_send![self.0, runModal] }
    }
}
