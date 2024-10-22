#![no_main]

use crate::cocoa::*;

mod cocoa;
mod objc;

const LABEL_SIZE: f64 = 48.0;

#[derive(Default)]
struct App {
    window: NSWindow,
    label: NSText,
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
        self.window.set_titlebar_appears_transparent(true);
        self.window.set_min_size(NSSize::new(320.0, 240.0));
        let screen_frame = self.window.screen().frame();
        let window_frame = self.window.frame();
        let window_x = (screen_frame.width - window_frame.width) / 2.0;
        let window_y = (screen_frame.height - window_frame.height) / 2.0;
        self.window.set_frame(
            NSRect::new(window_x, window_y, window_frame.width, window_frame.height),
            true,
        );
        self.window
            .set_background_color(NSColor::from_rgba(0x05, 0x44, 0x5e, 0xff));
        self.window.set_frame_autosave_name("window");
        self.window.set_delegate(self);

        // Create label
        self.label.set_string("Hello macOS!");
        self.label.set_frame(NSRect::new(
            0.0,
            (self.window.frame().height - LABEL_SIZE) / 2.0,
            self.window.frame().width,
            LABEL_SIZE,
        ));
        self.label.set_font(NSFont::system_font_of_size(LABEL_SIZE));
        self.label.set_alignment(NS_TEXT_ALIGNMENT_CENTER);
        self.label.set_editable(false);
        self.label.set_selectable(false);
        self.label.set_draws_background(false);
        self.window
            .content_view()
            .add_subview(self.label.as_ns_view());

        self.window.make_key_and_order_front();
    }

    fn should_terminate_after_last_window_closed(&self) -> bool {
        true
    }
}

impl NSWindowDelegate for App {
    fn did_resize(&self) {
        self.label.set_frame(NSRect::new(
            0.0,
            (self.window.frame().height - LABEL_SIZE) / 2.0,
            self.window.frame().width,
            LABEL_SIZE,
        ));
    }
}

#[no_mangle]
pub extern "C" fn main() {
    let app = App::default();
    let application = NSApplication::shared_application();
    application.set_delegate(&app);
    application.run();
}
