use std::cell::Cell;
use std::ffi::c_void;
use std::mem::size_of_val;
use std::ptr::{null, null_mut};

use objc2::rc::autoreleasepool;
use objc2::runtime::{AnyObject as Object, Bool, NSObject};
use objc2::{class, define_class, msg_send, sel, ClassType, DefinedClass};

use crate::cocoa::{
    ns_string, MTLClearColor, MTLCreateSystemDefaultDevice, NSApp, NSAppearanceNameDarkAqua,
    NSPoint, NSRect, NSSize, MTL_PIXEL_FORMAT_BGRA8_UNORM, MTL_PRIMITIVE_TYPE_TRIANGLE,
    NS_APPLICATION_ACTIVATION_POLICY_REGULAR, NS_BACKING_STORE_BUFFERED, NS_VIEW_HEIGHT_SIZABLE,
    NS_VIEW_WIDTH_SIZABLE, NS_WINDOW_STYLE_MASK_CLOSABLE, NS_WINDOW_STYLE_MASK_MINIATURIZABLE,
    NS_WINDOW_STYLE_MASK_RESIZABLE, NS_WINDOW_STYLE_MASK_TITLED,
};

mod cocoa;

#[repr(C, align(16))]
struct Vertex {
    position: [f32; 2],
    padding: [f32; 2],
    color: [f32; 4],
}

static VERTICES: [Vertex; 3] = [
    Vertex {
        position: [0.0, 0.75],
        padding: [0.0; 2],
        color: [1.0, 0.1, 0.1, 1.0],
    },
    Vertex {
        position: [-0.7, -0.6],
        padding: [0.0; 2],
        color: [0.1, 1.0, 0.2, 1.0],
    },
    Vertex {
        position: [0.7, -0.6],
        padding: [0.0; 2],
        color: [0.1, 0.3, 1.0, 1.0],
    },
];

#[derive(Default)]
struct RendererIvars {
    command_queue: Cell<*mut Object>,
    pipeline_state: Cell<*mut Object>,
}

define_class!(
    #[unsafe(super(NSObject))]
    #[name = "Renderer"]
    #[ivars = RendererIvars]
    struct Renderer;

    impl Renderer {
        #[unsafe(method(mtkView:drawableSizeWillChange:))]
        fn _drawable_size_will_change(&self, view: *mut Object, size: NSSize) {
            self.drawable_size_will_change(view, size);
        }

        #[unsafe(method(drawInMTKView:))]
        fn _draw(&self, view: *mut Object) { self.draw(view); }
    }
);

impl Renderer {
    fn configure(&self, view: *mut Object) -> bool {
        unsafe {
            let device: *mut Object = msg_send![view, device];
            let bundle: *mut Object = msg_send![class!(NSBundle), mainBundle];
            let library_url: *mut Object = msg_send![bundle,
                URLForResource:ns_string!("default"),
                withExtension:ns_string!("metallib")];
            let mut error: *mut Object = null_mut();
            let library: *mut Object =
                msg_send![device, newLibraryWithURL:library_url, error:&mut error];
            if library.is_null() {
                eprintln!("Could not load Metal library");
                return false;
            }

            let descriptor: *mut Object = msg_send![class!(MTLRenderPipelineDescriptor), new];
            let vertex_function: *mut Object =
                msg_send![library, newFunctionWithName:ns_string!("vertex_main")];
            let fragment_function: *mut Object =
                msg_send![library, newFunctionWithName:ns_string!("fragment_main")];
            let _: () = msg_send![descriptor, setVertexFunction:vertex_function];
            let _: () = msg_send![descriptor, setFragmentFunction:fragment_function];

            let color_attachments: *mut Object = msg_send![descriptor, colorAttachments];
            let color_attachment: *mut Object =
                msg_send![color_attachments, objectAtIndexedSubscript:0usize];
            let pixel_format: usize = msg_send![view, colorPixelFormat];
            let _: () = msg_send![color_attachment, setPixelFormat:pixel_format];

            let pipeline_state: *mut Object = msg_send![device, newRenderPipelineStateWithDescriptor:descriptor, error:&mut error];
            if pipeline_state.is_null() {
                eprintln!("Could not create Metal pipeline");
                return false;
            }

            let command_queue: *mut Object = msg_send![device, newCommandQueue];
            self.ivars().pipeline_state.set(pipeline_state);
            self.ivars().command_queue.set(command_queue);
            true
        }
    }

    fn drawable_size_will_change(&self, _view: *mut Object, _size: NSSize) {}

    fn draw(&self, view: *mut Object) {
        unsafe {
            let render_pass: *mut Object = msg_send![view, currentRenderPassDescriptor];
            let drawable: *mut Object = msg_send![view, currentDrawable];
            if render_pass.is_null() || drawable.is_null() {
                return;
            }

            let command_queue = self.ivars().command_queue.get();
            let command_buffer: *mut Object = msg_send![command_queue, commandBuffer];
            let _: () = msg_send![command_buffer, setLabel:ns_string!("Rainbow Triangle")];

            let encoder: *mut Object =
                msg_send![command_buffer, renderCommandEncoderWithDescriptor:render_pass];
            let _: () = msg_send![encoder, setLabel:ns_string!("Triangle Render Pass")];
            let _: () =
                msg_send![encoder, setRenderPipelineState:self.ivars().pipeline_state.get()];
            let _: () = msg_send![encoder,
                setVertexBytes:VERTICES.as_ptr().cast::<c_void>(),
                length:size_of_val(&VERTICES),
                atIndex:0usize];
            let _: () = msg_send![encoder,
                drawPrimitives:MTL_PRIMITIVE_TYPE_TRIANGLE,
                vertexStart:0usize,
                vertexCount:VERTICES.len()];
            let _: () = msg_send![encoder, endEncoding];

            let _: () = msg_send![command_buffer, presentDrawable:drawable];
            let _: () = msg_send![command_buffer, commit];
        }
    }
}

define_class!(
    #[unsafe(super(NSObject))]
    #[name = "AppDelegate"]
    struct AppDelegate;

    impl AppDelegate {
        #[unsafe(method(applicationDidFinishLaunching:))]
        fn _did_finish_launching(&self, notification: *const Object) {
            self.did_finish_launching(notification);
        }

        #[unsafe(method(applicationShouldTerminateAfterLastWindowClosed:))]
        fn _should_terminate_after_last_window_closed(&self, _sender: *const Object) -> Bool {
            Bool::YES
        }
    }
);

impl AppDelegate {
    fn did_finish_launching(&self, _notification: *const Object) {
        unsafe {
            let main_menu: *mut Object = msg_send![class!(NSMenu), new];
            let _: () = msg_send![NSApp, setMainMenu:main_menu];

            let app_menu_item: *mut Object = msg_send![class!(NSMenuItem), new];
            let _: () = msg_send![main_menu, addItem:app_menu_item];

            let app_menu: *mut Object = msg_send![class!(NSMenu), new];
            let _: () = msg_send![app_menu_item, setSubmenu:app_menu];
            let quit_item: *mut Object = msg_send![class!(NSMenuItem), alloc];
            let quit_item: *mut Object = msg_send![quit_item,
                initWithTitle:ns_string!("Quit Triangle"),
                action:sel!(terminate:),
                keyEquivalent:ns_string!("q")];
            let _: () = msg_send![app_menu, addItem:quit_item];

            let window: *mut Object = msg_send![class!(NSWindow), alloc];
            let window: *mut Object = msg_send![window,
                initWithContentRect:NSRect::new(NSPoint::new(0.0, 0.0), NSSize::new(900.0, 650.0)),
                styleMask:NS_WINDOW_STYLE_MASK_TITLED | NS_WINDOW_STYLE_MASK_CLOSABLE | NS_WINDOW_STYLE_MASK_MINIATURIZABLE | NS_WINDOW_STYLE_MASK_RESIZABLE,
                backing:NS_BACKING_STORE_BUFFERED,
                defer:false];
            let _: () = msg_send![window, setTitle:ns_string!("Triangle")];
            let appearance: *mut Object =
                msg_send![class!(NSAppearance), appearanceNamed:NSAppearanceNameDarkAqua];
            let _: () = msg_send![window, setAppearance:appearance];
            let screen: *mut Object = msg_send![window, screen];
            let screen_frame: NSRect = msg_send![screen, frame];
            let window_frame: NSRect = msg_send![window, frame];
            let window_x = (screen_frame.size.width - window_frame.size.width) / 2.0;
            let window_y = (screen_frame.size.height - window_frame.size.height) / 2.0;
            let centered_frame = NSRect::new(NSPoint::new(window_x, window_y), window_frame.size);
            let _: () = msg_send![window, setFrame:centered_frame, display:true];
            let _: () = msg_send![window, setMinSize:NSSize::new(480.0, 360.0)];

            let device = MTLCreateSystemDefaultDevice();
            if device.is_null() {
                eprintln!("Metal is not supported on this Mac");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            }

            let content_view: *mut Object = msg_send![window, contentView];
            let bounds: NSRect = msg_send![content_view, bounds];
            let metal_view: *mut Object = msg_send![class!(MTKView), alloc];
            let metal_view: *mut Object =
                msg_send![metal_view, initWithFrame:bounds, device:device];
            let _: () = msg_send![metal_view,
                setAutoresizingMask:NS_VIEW_WIDTH_SIZABLE | NS_VIEW_HEIGHT_SIZABLE];
            let _: () = msg_send![metal_view, setColorPixelFormat:MTL_PIXEL_FORMAT_BGRA8_UNORM];
            let _: () = msg_send![metal_view,
                setClearColor:MTLClearColor::new(0.015, 0.02, 0.04, 1.0)];
            let _: () = msg_send![metal_view, setPreferredFramesPerSecond:60isize];

            let renderer: *mut Renderer = msg_send![class!(Renderer), new];
            if !(&*renderer).configure(metal_view) {
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            }
            let _: () = msg_send![metal_view, setDelegate:renderer];
            let _: () = msg_send![window, setContentView:metal_view];

            let _: Bool =
                msg_send![NSApp, setActivationPolicy:NS_APPLICATION_ACTIVATION_POLICY_REGULAR];
            let _: () = msg_send![NSApp, activateIgnoringOtherApps:true];
            let _: () = msg_send![window, makeKeyAndOrderFront:null::<Object>()];
        }
    }
}

fn main() {
    let _ = Renderer::class();
    let _ = AppDelegate::class();

    autoreleasepool(|_| unsafe {
        let app: *mut Object = msg_send![class!(NSApplication), sharedApplication];
        let delegate: *mut Object = msg_send![class!(AppDelegate), new];
        let _: () = msg_send![app, setDelegate:delegate];
        let _: () = msg_send![app, run];
    });
}
