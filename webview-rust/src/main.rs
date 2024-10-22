#![no_main]

use crate::cocoa::*;

mod cocoa;
mod objc;

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
        self.window.set_delegate(self);

        // Create webview
        self.webview.set_frame(self.window.content_view().bounds());
        let app_path = NSBundle::main_bundle().url_for_resource_with_extension("app", "html");
        self.webview
            .load_request(NSURLRequest::request_with_url(app_path));
        self.window
            .content_view()
            .add_subview(self.webview.as_ns_view());

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
    let app = App::default();
    let application = NSApplication::shared_application();
    application.set_delegate(&app);
    application.run();
}
