use std::cell::OnceCell;
use std::ptr::null;

use objc2::rc::{Allocated, Retained, autoreleasepool};
use objc2::runtime::{AnyObject as Object, Bool, NSObject};
use objc2::{ClassType, DefinedClass, class, define_class, msg_send, sel};

use crate::cocoa::{
    NS_APPLICATION_ACTIVATION_POLICY_REGULAR, NS_BACKING_STORE_BUFFERED,
    NS_WINDOW_STYLE_MASK_CLOSABLE, NS_WINDOW_STYLE_MASK_MINIATURIZABLE,
    NS_WINDOW_STYLE_MASK_RESIZABLE, NS_WINDOW_STYLE_MASK_TITLED, NSApp, NSAppearanceNameDarkAqua,
    NSFontAttributeName, NSForegroundColorAttributeName, NSPoint, NSRect, NSSize, NSView,
    ns_string,
};

mod cocoa;

// MARK: CanvasView
define_class!(
    #[unsafe(super(NSView))]
    #[name = "CanvasView"]
    struct CanvasView;

    impl CanvasView {
        #[unsafe(method(drawRect:))]
        fn _draw_rect(&self, dirty_rect: NSRect) { self.draw_rect(dirty_rect); }
    }
);

impl CanvasView {
    fn draw_rect(&self, _dirty_rect: NSRect) {
        unsafe {
            let text = ns_string!("Hello macOS!");

            let font: Retained<Object> = msg_send![class!(NSFont), systemFontOfSize:48.0];
            let color: Retained<Object> = msg_send![class!(NSColor), whiteColor];
            let keys: [*const Object; 2] = [NSFontAttributeName, NSForegroundColorAttributeName];
            let values: [*const Object; 2] = [&*font, &*color];
            let attributes: Retained<Object> = msg_send![class!(NSDictionary),
                dictionaryWithObjects:values.as_ptr(),
                forKeys:keys.as_ptr(),
                count:keys.len()];

            let size: NSSize = msg_send![text, sizeWithAttributes:&*attributes];
            let frame: NSRect = msg_send![self, frame];
            let rect = NSRect::new(
                NSPoint::new(
                    (frame.size.width - size.width) / 2.0,
                    (frame.size.height - size.height) / 2.0,
                ),
                size,
            );
            let _: () = msg_send![text, drawInRect:rect, withAttributes:&*attributes];
        }
    }
}

// MARK: AppDelegate
#[derive(Default)]
struct AppDelegateIvars {
    window: OnceCell<Retained<Object>>,
}

define_class!(
    #[unsafe(super(NSObject))]
    #[name = "AppDelegate"]
    #[ivars = AppDelegateIvars]
    struct AppDelegate;

    impl AppDelegate {
        #[unsafe(method_id(init))]
        fn _init(this: Allocated<Self>) -> Option<Retained<Self>> {
            unsafe { msg_send![super(this.set_ivars(AppDelegateIvars::default())), init] }
        }

        #[unsafe(method(applicationDidFinishLaunching:))]
        fn _did_finish_launching(&self, notification: &Object) { self.did_finish_launching(notification); }

        #[unsafe(method(applicationShouldTerminateAfterLastWindowClosed:))]
        fn _should_terminate_after_last_window_closed(&self, _: &Object) -> Bool { Bool::YES }

        #[unsafe(method(openAbout:))]
        fn _open_about(&self, _: Option<&Object>) { self.open_about(); }
    }
);

impl AppDelegate {
    fn did_finish_launching(&self, _notification: &Object) {
        unsafe {
            // Create menu
            let menubar: Retained<Object> = msg_send![class!(NSMenu), new];
            let _: () = msg_send![NSApp, setMainMenu:&*menubar];

            let menu_bar_item: Retained<Object> = msg_send![class!(NSMenuItem), new];
            let _: () = msg_send![&menubar, addItem:&*menu_bar_item];

            let app_menu: Retained<Object> = msg_send![class!(NSMenu), new];
            let _: () = msg_send![&menu_bar_item, setSubmenu:&*app_menu];

            let about_menu_item: Allocated<Object> = msg_send![class!(NSMenuItem), alloc];
            let about_menu_item: Retained<Object> = msg_send![about_menu_item,
                initWithTitle:ns_string!("About BassieTest"),
                action:sel!(openAbout:),
                keyEquivalent:ns_string!("")];
            let _: () = msg_send![&app_menu, addItem:&*about_menu_item];

            let separator_item: Retained<Object> = msg_send![class!(NSMenuItem), separatorItem];
            let _: () = msg_send![&app_menu, addItem:&*separator_item];

            let quit_menu_item: Allocated<Object> = msg_send![class!(NSMenuItem), alloc];
            let quit_menu_item: Retained<Object> = msg_send![quit_menu_item,
                initWithTitle:ns_string!("Quit BassieTest"),
                action:sel!(terminate:),
                keyEquivalent:ns_string!("q")];
            let _: () = msg_send![&app_menu, addItem:&*quit_menu_item];

            // Create window
            let window: Allocated<Object> = msg_send![class!(NSWindow), alloc];
            let window: Retained<Object> = msg_send![window,
                initWithContentRect:NSRect::new(NSPoint::new(0.0, 0.0), NSSize::new(1024.0, 768.0)),
                styleMask:NS_WINDOW_STYLE_MASK_TITLED | NS_WINDOW_STYLE_MASK_CLOSABLE | NS_WINDOW_STYLE_MASK_MINIATURIZABLE | NS_WINDOW_STYLE_MASK_RESIZABLE,
                backing:NS_BACKING_STORE_BUFFERED,
                defer:Bool::NO];
            let _: () = msg_send![&window, setReleasedWhenClosed:Bool::NO];
            let _: () = msg_send![&window, setTitle:ns_string!("BassieTest")];
            let _: () = msg_send![&window, setTitlebarAppearsTransparent:Bool::YES];
            let appearance: Option<Retained<Object>> =
                msg_send![class!(NSAppearance), appearanceNamed:NSAppearanceNameDarkAqua];
            if let Some(appearance) = appearance {
                let _: () = msg_send![&window, setAppearance:&*appearance];
            }
            let screen: Option<Retained<Object>> = msg_send![&window, screen];
            if let Some(screen) = screen {
                let screen_frame: NSRect = msg_send![&screen, frame];
                let window_frame: NSRect = msg_send![&window, frame];
                let window_x = (screen_frame.size.width - window_frame.size.width) / 2.0;
                let window_y = (screen_frame.size.height - window_frame.size.height) / 2.0;
                let _: () = msg_send![&window, setFrame:NSRect::new(NSPoint::new(window_x, window_y), window_frame.size), display:Bool::YES];
            }
            let _: () = msg_send![&window, setMinSize:NSSize::new(320.0, 240.0)];
            let background_color: Retained<Object> = msg_send![class!(NSColor), colorWithRed:(0x05 as f64) / 255.0, green:(0x44 as f64) / 255.0, blue:(0x5e as f64) / 255.0, alpha:1.0];
            let _: () = msg_send![&window, setBackgroundColor:&*background_color];
            let _: Bool = msg_send![&window, setFrameAutosaveName:ns_string!("window")];

            // Create canvas
            let canvas_view: Retained<CanvasView> = msg_send![class!(CanvasView), new];
            let _: () = msg_send![&window, setContentView:&*canvas_view];

            if self.ivars().window.set(window).is_err() {
                eprintln!("Application delegate was already initialized");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            }

            // Show window
            let _: Bool =
                msg_send![NSApp, setActivationPolicy:NS_APPLICATION_ACTIVATION_POLICY_REGULAR];
            let _: () = msg_send![NSApp, activateIgnoringOtherApps:Bool::YES];
            let window = self.ivars().window.get().unwrap();
            let _: () = msg_send![window, makeKeyAndOrderFront:null::<Object>()];
        }
    }

    fn open_about(&self) {
        unsafe {
            let _: () = msg_send![NSApp, orderFrontStandardAboutPanel:null::<Object>()];
        }
    }
}

// MARK: Main
fn main() {
    // Register classes
    let _ = CanvasView::class();
    let _ = AppDelegate::class();

    // Start application
    autoreleasepool(|_| unsafe {
        let app: Retained<Object> = msg_send![class!(NSApplication), sharedApplication];
        let delegate: Retained<AppDelegate> = msg_send![class!(AppDelegate), new];
        let _: () = msg_send![&app, setDelegate:&*delegate];
        let _: () = msg_send![&app, run];
    });
}
