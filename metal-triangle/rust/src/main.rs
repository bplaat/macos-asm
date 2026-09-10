use std::cell::OnceCell;
use std::ffi::{c_void, CStr};
use std::mem::size_of_val;
use std::ptr::{null, null_mut};

use objc2::rc::{autoreleasepool, Allocated, Retained};
use objc2::runtime::{AnyObject as Object, Bool, NSObject};
use objc2::{class, define_class, msg_send, sel, ClassType, DefinedClass};

use crate::cocoa::{
    dispatch_data_create, ns_string, MTLClearColor, MTLCreateSystemDefaultDevice, NSApp,
    NSAppearanceNameDarkAqua, NSPoint, NSRect, NSSize, MTL_PIXEL_FORMAT_BGRA8_UNORM,
    MTL_PRIMITIVE_TYPE_TRIANGLE, NS_APPLICATION_ACTIVATION_POLICY_REGULAR,
    NS_BACKING_STORE_BUFFERED, NS_VIEW_HEIGHT_SIZABLE, NS_VIEW_WIDTH_SIZABLE,
    NS_WINDOW_STYLE_MASK_CLOSABLE, NS_WINDOW_STYLE_MASK_MINIATURIZABLE,
    NS_WINDOW_STYLE_MASK_RESIZABLE, NS_WINDOW_STYLE_MASK_TITLED,
};

mod cocoa;

static EMBEDDED_METALLIB: &[u8] = include_bytes!("../target/default.metallib");

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
    state: OnceCell<RendererState>,
}

struct RendererState {
    command_queue: Retained<Object>,
    pipeline_state: Retained<Object>,
}

define_class!(
    #[unsafe(super(NSObject))]
    #[name = "Renderer"]
    #[ivars = RendererIvars]
    struct Renderer;

    impl Renderer {
        #[unsafe(method_id(init))]
        fn _init(this: Allocated<Self>) -> Option<Retained<Self>> {
            unsafe { msg_send![super(this.set_ivars(RendererIvars::default())), init] }
        }

        #[unsafe(method(mtkView:drawableSizeWillChange:))]
        fn _drawable_size_will_change(&self, view: &Object, size: NSSize) {
            self.drawable_size_will_change(view, size);
        }

        #[unsafe(method(drawInMTKView:))]
        fn _draw(&self, view: &Object) { self.draw(view); }
    }
);

impl Renderer {
    fn configure(&self, view: &Object) -> bool {
        unsafe {
            let device: Option<Retained<Object>> = msg_send![view, device];
            let Some(device) = device else {
                eprintln!("Metal view has no device");
                return false;
            };
            let library_data = Retained::from_raw(dispatch_data_create(
                EMBEDDED_METALLIB.as_ptr().cast::<c_void>(),
                EMBEDDED_METALLIB.len(),
                null_mut(),
                null_mut(),
            ));
            let Some(library_data) = library_data else {
                eprintln!("Could not create Metal library data");
                return false;
            };
            let mut library_error: Option<Retained<Object>> = None;
            let library: Option<Retained<Object>> =
                msg_send![&device, newLibraryWithData:&*library_data, error:&mut library_error];
            let Some(library) = library else {
                eprintln!("Could not load Metal library: {library_error:?}");
                return false;
            };

            let descriptor: Retained<Object> = msg_send![class!(MTLRenderPipelineDescriptor), new];
            let vertex_function: Option<Retained<Object>> =
                msg_send![&library, newFunctionWithName:ns_string!("vertex_main")];
            let fragment_function: Option<Retained<Object>> =
                msg_send![&library, newFunctionWithName:ns_string!("fragment_main")];
            let (Some(vertex_function), Some(fragment_function)) =
                (vertex_function, fragment_function)
            else {
                eprintln!("Could not load Metal shader functions");
                return false;
            };
            let _: () = msg_send![&descriptor, setVertexFunction:&*vertex_function];
            let _: () = msg_send![&descriptor, setFragmentFunction:&*fragment_function];

            let color_attachments: Retained<Object> = msg_send![&descriptor, colorAttachments];
            let color_attachment: Retained<Object> =
                msg_send![&color_attachments, objectAtIndexedSubscript:0usize];
            let pixel_format: usize = msg_send![view, colorPixelFormat];
            let _: () = msg_send![&color_attachment, setPixelFormat:pixel_format];

            let mut pipeline_error: Option<Retained<Object>> = None;
            let pipeline_state: Option<Retained<Object>> = msg_send![&device,
                newRenderPipelineStateWithDescriptor:&*descriptor,
                error:&mut pipeline_error];
            let Some(pipeline_state) = pipeline_state else {
                eprintln!("Could not create Metal pipeline: {pipeline_error:?}");
                return false;
            };

            let command_queue: Option<Retained<Object>> = msg_send![&device, newCommandQueue];
            let Some(command_queue) = command_queue else {
                eprintln!("Could not create Metal command queue");
                return false;
            };

            let state = RendererState {
                command_queue,
                pipeline_state,
            };
            if self.ivars().state.set(state).is_err() {
                eprintln!("Renderer was already configured");
                return false;
            }
            true
        }
    }

    fn drawable_size_will_change(&self, _view: &Object, _size: NSSize) {}

    fn draw(&self, view: &Object) {
        unsafe {
            let render_pass: Option<Retained<Object>> =
                msg_send![view, currentRenderPassDescriptor];
            let drawable: Option<Retained<Object>> = msg_send![view, currentDrawable];
            let (Some(render_pass), Some(drawable)) = (render_pass, drawable) else {
                return;
            };

            let Some(state) = self.ivars().state.get() else {
                return;
            };
            let command_buffer: Option<Retained<Object>> =
                msg_send![&state.command_queue, commandBuffer];
            let Some(command_buffer) = command_buffer else {
                return;
            };
            let _: () = msg_send![&command_buffer, setLabel:ns_string!("Rainbow Triangle")];

            let encoder: Option<Retained<Object>> = msg_send![&command_buffer,
                renderCommandEncoderWithDescriptor:&*render_pass];
            let Some(encoder) = encoder else {
                return;
            };
            let _: () = msg_send![&encoder, setLabel:ns_string!("Triangle Render Pass")];
            let _: () = msg_send![&encoder, setRenderPipelineState:&*state.pipeline_state];
            let _: () = msg_send![&encoder,
                setVertexBytes:VERTICES.as_ptr().cast::<c_void>(),
                length:size_of_val(&VERTICES),
                atIndex:0usize];
            let _: () = msg_send![&encoder,
                drawPrimitives:MTL_PRIMITIVE_TYPE_TRIANGLE,
                vertexStart:0usize,
                vertexCount:VERTICES.len()];
            let _: () = msg_send![&encoder, endEncoding];

            let _: () = msg_send![&command_buffer, presentDrawable:&*drawable];
            let _: () = msg_send![&command_buffer, commit];
        }
    }
}

#[derive(Default)]
struct AppDelegateIvars {
    state: OnceCell<AppState>,
}

struct AppState {
    window: Retained<Object>,
    _renderer: Retained<Renderer>,
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
        fn _did_finish_launching(&self, notification: &Object) {
            self.did_finish_launching(notification);
        }

        #[unsafe(method(applicationShouldTerminateAfterLastWindowClosed:))]
        fn _should_terminate_after_last_window_closed(&self, _sender: &Object) -> Bool {
            Bool::YES
        }
    }
);

impl AppDelegate {
    fn did_finish_launching(&self, _notification: &Object) {
        unsafe {
            let main_menu: Retained<Object> = msg_send![class!(NSMenu), new];
            let _: () = msg_send![NSApp, setMainMenu:&*main_menu];

            let app_menu_item: Retained<Object> = msg_send![class!(NSMenuItem), new];
            let _: () = msg_send![&main_menu, addItem:&*app_menu_item];

            let app_menu: Retained<Object> = msg_send![class!(NSMenu), new];
            let _: () = msg_send![&app_menu_item, setSubmenu:&*app_menu];
            let quit_item: Allocated<Object> = msg_send![class!(NSMenuItem), alloc];
            let quit_item: Retained<Object> = msg_send![quit_item,
                initWithTitle:ns_string!("Quit Triangle"),
                action:sel!(terminate:),
                keyEquivalent:ns_string!("q")];
            let _: () = msg_send![&app_menu, addItem:&*quit_item];

            let window: Allocated<Object> = msg_send![class!(NSWindow), alloc];
            let window: Retained<Object> = msg_send![window,
                initWithContentRect:NSRect::new(NSPoint::new(0.0, 0.0), NSSize::new(900.0, 650.0)),
                styleMask:NS_WINDOW_STYLE_MASK_TITLED | NS_WINDOW_STYLE_MASK_CLOSABLE | NS_WINDOW_STYLE_MASK_MINIATURIZABLE | NS_WINDOW_STYLE_MASK_RESIZABLE,
                backing:NS_BACKING_STORE_BUFFERED,
                defer:Bool::NO];
            let _: () = msg_send![&window, setTitle:ns_string!("Triangle")];
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
                let centered_frame =
                    NSRect::new(NSPoint::new(window_x, window_y), window_frame.size);
                let _: () = msg_send![&window, setFrame:centered_frame, display:Bool::YES];
            }
            let _: () = msg_send![&window, setMinSize:NSSize::new(480.0, 360.0)];

            let device = Retained::from_raw(MTLCreateSystemDefaultDevice());
            let Some(device) = device else {
                eprintln!("Metal is not supported on this Mac");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            };
            let device_name: Retained<Object> = msg_send![&device, name];
            let device_name_utf8: *const std::ffi::c_char = msg_send![&device_name, UTF8String];
            let supports_metal_4: Bool = msg_send![&device, supportsFamily:5002isize];
            let supports_metal_3: Bool = msg_send![&device, supportsFamily:5001isize];
            let metal_version = if supports_metal_4.as_bool() {
                "4"
            } else if supports_metal_3.as_bool() {
                "3"
            } else {
                "2 or earlier"
            };
            eprintln!(
                "Metal version: {metal_version}, device: {}",
                CStr::from_ptr(device_name_utf8).to_string_lossy(),
            );

            let content_view: Option<Retained<Object>> = msg_send![&window, contentView];
            let Some(content_view) = content_view else {
                eprintln!("Window has no content view");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            };
            let bounds: NSRect = msg_send![&content_view, bounds];
            let metal_view: Allocated<Object> = msg_send![class!(MTKView), alloc];
            let metal_view: Retained<Object> =
                msg_send![metal_view, initWithFrame:bounds, device:&*device];
            let _: () = msg_send![&metal_view,
                setAutoresizingMask:NS_VIEW_WIDTH_SIZABLE | NS_VIEW_HEIGHT_SIZABLE];
            let _: () = msg_send![&metal_view, setColorPixelFormat:MTL_PIXEL_FORMAT_BGRA8_UNORM];
            let _: () = msg_send![&metal_view,
                setClearColor:MTLClearColor::new(0.015, 0.02, 0.04, 1.0)];
            let _: () = msg_send![&metal_view, setPreferredFramesPerSecond:60isize];

            let renderer: Retained<Renderer> = msg_send![class!(Renderer), new];
            if !renderer.configure(&metal_view) {
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            }
            let _: () = msg_send![&metal_view, setDelegate:&*renderer];
            let _: () = msg_send![&window, setContentView:&*metal_view];

            let state = AppState {
                window,
                _renderer: renderer,
            };
            if self.ivars().state.set(state).is_err() {
                eprintln!("Application delegate was already initialized");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            }

            let _: Bool =
                msg_send![NSApp, setActivationPolicy:NS_APPLICATION_ACTIVATION_POLICY_REGULAR];
            let _: () = msg_send![NSApp, activateIgnoringOtherApps:Bool::YES];
            let state = self.ivars().state.get().unwrap();
            let _: () = msg_send![&state.window, makeKeyAndOrderFront:null::<Object>()];
        }
    }
}

fn main() {
    let _ = Renderer::class();
    let _ = AppDelegate::class();

    autoreleasepool(|_| unsafe {
        let app: Retained<Object> = msg_send![class!(NSApplication), sharedApplication];
        let delegate: Retained<AppDelegate> = msg_send![class!(AppDelegate), new];
        let _: () = msg_send![&app, setDelegate:&*delegate];
        let _: () = msg_send![&app, run];
    });
}
