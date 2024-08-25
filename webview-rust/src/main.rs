#![no_main]

use objc::{sel, sel_impl};

use crate::cocoa::{
    NSApplication, NSApplicationDelegate, NSBundle, NSMenu, NSMenuItem, NSRect, NSSize,
    NSURLRequest, NSWindow, NSWindowDelegate, WKWebView,
};

mod cocoa;

#[derive(Default)]
struct App {
    window: NSWindow,
    webview: WKWebView,
}
impl NSApplicationDelegate for App {
    fn did_finish_launching(&self) {
        // Create menu
        let menubar = NSMenu::new();
        let app_menu_item = NSMenuItem::new();
        let app_menu = NSMenu::new();
        let quit_menu_item =
            NSMenuItem::new_with_title_action_and_key("Quit BassieTest", sel!(terminate:), "q");
        app_menu.add_item(quit_menu_item);
        app_menu_item.set_submenu(app_menu);
        menubar.add_item(app_menu_item);
        NSApplication::shared_application().set_main_menu(menubar);

        // Create window
        self.window.set_title("BassieTest");
        self.window.set_min_size(NSSize::new(320.0, 240.0));
        let screen_frame = self.window.screen().frame();
        let window_frame = self.window.frame();
        let window_x = (screen_frame.width - window_frame.width) / 2.0;
        let window_y = (screen_frame.height - window_frame.height) / 2.0;
        self.window.set_frame(
            NSRect::new(window_x, window_y, window_frame.width, window_frame.height),
            true,
        );
        self.window.set_frame_autosave_name("window");
        self.window.set_delegate_from_ref(self);

        // Create webview
        let content_view = self.window.content_view();
        self.webview.set_frame(content_view.bounds());
        let app_path = NSBundle::main_bundle().url_for_resource_with_extension("app", "html");
        let request = NSURLRequest::request_with_url(app_path);
        self.webview.load_request(request.0);
        content_view.add_subview(self.webview.0);

        self.window.make_key_and_order_front();
    }

    fn should_terminate_after_last_window_closed(&self) -> bool {
        true
    }
}

impl NSWindowDelegate for App {
    fn did_resize(&self) {
        self.webview.set_frame(self.window.content_view().bounds());
    }
}

#[no_mangle]
pub extern "C" fn main() {
    let app = NSApplication::shared_application();
    app.set_delegate(App::default());
    app.run();
}
