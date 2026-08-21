use std::cell::OnceCell;
use std::ffi::{CStr, c_char, c_void};
use std::mem::{offset_of, size_of, size_of_val};
use std::ptr::null;

use objc2::rc::{Allocated, Retained, autoreleasepool};
use objc2::runtime::{AnyObject as Object, Bool, NSObject};
use objc2::{ClassType, DefinedClass, class, define_class, extern_class, msg_send, sel};

use crate::cocoa::{
    NS_APPLICATION_ACTIVATION_POLICY_REGULAR, NS_BACKING_STORE_BUFFERED,
    NS_OPENGL_CONTEXT_PARAMETER_SWAP_INTERVAL, NS_OPENGL_PFA_ACCELERATED, NS_OPENGL_PFA_ALPHA_SIZE,
    NS_OPENGL_PFA_COLOR_SIZE, NS_OPENGL_PFA_DOUBLE_BUFFER, NS_OPENGL_PFA_OPENGL_PROFILE,
    NS_OPENGL_PROFILE_VERSION_4_1_CORE, NS_VIEW_HEIGHT_SIZABLE, NS_VIEW_WIDTH_SIZABLE,
    NS_WINDOW_STYLE_MASK_CLOSABLE, NS_WINDOW_STYLE_MASK_MINIATURIZABLE,
    NS_WINDOW_STYLE_MASK_RESIZABLE, NS_WINDOW_STYLE_MASK_TITLED, NSApp, NSAppearanceNameDarkAqua,
    NSPoint, NSRect, NSSize, ns_string,
};
use crate::gl::*;

mod cocoa;
mod gl;

#[repr(C)]
struct Vertex {
    position: [f32; 2],
    color: [f32; 4],
}

static VERTICES: [Vertex; 3] = [
    Vertex {
        position: [0.0, 0.75],
        color: [1.0, 0.1, 0.1, 1.0],
    },
    Vertex {
        position: [-0.7, -0.6],
        color: [0.1, 1.0, 0.2, 1.0],
    },
    Vertex {
        position: [0.7, -0.6],
        color: [0.1, 0.3, 1.0, 1.0],
    },
];

static VERTEX_SHADER_SOURCE: &[u8] = concat!(include_str!("Shaders.vert"), "\0").as_bytes();
static FRAGMENT_SHADER_SOURCE: &[u8] = concat!(include_str!("Shaders.frag"), "\0").as_bytes();

unsafe fn compile_shader(shader_type: GLenum, source: &[u8]) -> GLuint {
    unsafe {
        let shader = glCreateShader(shader_type);
        let source_pointer = source.as_ptr().cast::<c_char>();
        glShaderSource(shader, 1, &source_pointer, null());
        glCompileShader(shader);

        let mut compiled = GL_FALSE;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &mut compiled);
        if compiled == GL_TRUE {
            return shader;
        }

        let mut log_length = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &mut log_length);
        let mut log = vec![0i8; log_length.max(1) as usize];
        glGetShaderInfoLog(
            shader,
            log.len() as GLsizei,
            null::<GLsizei>().cast_mut(),
            log.as_mut_ptr(),
        );
        eprintln!(
            "Could not compile OpenGL shader: {}",
            CStr::from_ptr(log.as_ptr()).to_string_lossy()
        );
        glDeleteShader(shader);
        0
    }
}

unsafe fn create_program() -> GLuint {
    unsafe {
        let vertex_shader = compile_shader(GL_VERTEX_SHADER, VERTEX_SHADER_SOURCE);
        if vertex_shader == 0 {
            return 0;
        }

        let fragment_shader = compile_shader(GL_FRAGMENT_SHADER, FRAGMENT_SHADER_SOURCE);
        if fragment_shader == 0 {
            glDeleteShader(vertex_shader);
            return 0;
        }

        let program = glCreateProgram();
        glAttachShader(program, vertex_shader);
        glAttachShader(program, fragment_shader);
        glLinkProgram(program);
        glDeleteShader(vertex_shader);
        glDeleteShader(fragment_shader);

        let mut linked = GL_FALSE;
        glGetProgramiv(program, GL_LINK_STATUS, &mut linked);
        if linked == GL_TRUE {
            return program;
        }

        let mut log_length = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &mut log_length);
        let mut log = vec![0i8; log_length.max(1) as usize];
        glGetProgramInfoLog(
            program,
            log.len() as GLsizei,
            null::<GLsizei>().cast_mut(),
            log.as_mut_ptr(),
        );
        eprintln!(
            "Could not link OpenGL program: {}",
            CStr::from_ptr(log.as_ptr()).to_string_lossy()
        );
        glDeleteProgram(program);
        0
    }
}

extern_class!(
    #[unsafe(super(NSObject))]
    #[name = "NSOpenGLView"]
    struct NSOpenGLView;
);

#[derive(Default)]
struct RendererIvars {
    state: OnceCell<RendererState>,
}

struct RendererState {
    program: GLuint,
    vertex_array: GLuint,
    vertex_buffer: GLuint,
}

impl Drop for RendererState {
    fn drop(&mut self) {
        unsafe {
            glDeleteBuffers(1, &self.vertex_buffer);
            glDeleteVertexArrays(1, &self.vertex_array);
            glDeleteProgram(self.program);
        }
    }
}

define_class!(
    #[unsafe(super(NSOpenGLView, NSObject))]
    #[name = "RendererView"]
    #[ivars = RendererIvars]
    struct RendererView;

    impl RendererView {
        #[unsafe(method_id(initWithFrame:pixelFormat:))]
        fn _init(
            this: Allocated<Self>,
            frame: NSRect,
            pixel_format: &Object,
        ) -> Option<Retained<Self>> {
            unsafe {
                msg_send![
                    super(this.set_ivars(RendererIvars::default())),
                    initWithFrame:frame,
                    pixelFormat:pixel_format
                ]
            }
        }

        #[unsafe(method(prepareOpenGL))]
        fn _prepare_opengl(&self) {
            unsafe {
                let _: () = msg_send![super(self), prepareOpenGL];
            }
            self.prepare_opengl();
        }

        #[unsafe(method(reshape))]
        fn _reshape(&self) {
            unsafe {
                let _: () = msg_send![super(self), reshape];
            }
            self.reshape();
        }

        #[unsafe(method(drawRect:))]
        fn _draw(&self, dirty_rect: NSRect) {
            self.draw(dirty_rect);
        }
    }
);

impl RendererView {
    fn prepare_opengl(&self) {
        unsafe {
            let context: Option<Retained<Object>> = msg_send![self, openGLContext];
            let Some(context) = context else {
                eprintln!("OpenGL view has no context");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            };
            let _: () = msg_send![&context, makeCurrentContext];

            let version = CStr::from_ptr(glGetString(GL_VERSION).cast());
            let renderer = CStr::from_ptr(glGetString(GL_RENDERER).cast());
            eprintln!(
                "OpenGL version: {}, device: {}",
                version.to_string_lossy(),
                renderer.to_string_lossy()
            );

            let swap_interval = 1i32;
            let _: () = msg_send![&context,
                setValues:&swap_interval,
                forParameter:NS_OPENGL_CONTEXT_PARAMETER_SWAP_INTERVAL];

            let program = create_program();
            if program == 0 {
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            }

            let mut vertex_array = 0;
            glGenVertexArrays(1, &mut vertex_array);
            glBindVertexArray(vertex_array);

            let mut vertex_buffer = 0;
            glGenBuffers(1, &mut vertex_buffer);
            glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer);
            glBufferData(
                GL_ARRAY_BUFFER,
                size_of_val(&VERTICES) as GLsizeiptr,
                VERTICES.as_ptr().cast::<c_void>(),
                GL_STATIC_DRAW,
            );
            glEnableVertexAttribArray(0);
            glVertexAttribPointer(
                0,
                2,
                GL_FLOAT,
                0,
                size_of::<Vertex>() as GLsizei,
                offset_of!(Vertex, position) as *const c_void,
            );
            glEnableVertexAttribArray(1);
            glVertexAttribPointer(
                1,
                4,
                GL_FLOAT,
                0,
                size_of::<Vertex>() as GLsizei,
                offset_of!(Vertex, color) as *const c_void,
            );
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            glBindVertexArray(0);
            glClearColor(0.015, 0.02, 0.04, 1.0);

            let state = RendererState {
                program,
                vertex_array,
                vertex_buffer,
            };
            if self.ivars().state.set(state).is_err() {
                eprintln!("OpenGL renderer was already initialized");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
            }
        }
    }

    fn reshape(&self) {
        unsafe {
            let context: Option<Retained<Object>> = msg_send![self, openGLContext];
            let Some(context) = context else { return };
            let _: () = msg_send![&context, makeCurrentContext];
            let bounds: NSRect = msg_send![self, bounds];
            let backing_bounds: NSRect = msg_send![self, convertRectToBacking:bounds];
            glViewport(
                0,
                0,
                backing_bounds.size.width as GLsizei,
                backing_bounds.size.height as GLsizei,
            );
        }
    }

    fn draw(&self, _dirty_rect: NSRect) {
        unsafe {
            let Some(state) = self.ivars().state.get() else {
                return;
            };
            let context: Option<Retained<Object>> = msg_send![self, openGLContext];
            let Some(context) = context else { return };
            let _: () = msg_send![&context, makeCurrentContext];

            glClear(GL_COLOR_BUFFER_BIT);
            glUseProgram(state.program);
            glBindVertexArray(state.vertex_array);
            glDrawArrays(GL_TRIANGLES, 0, VERTICES.len() as GLsizei);
            glBindVertexArray(0);
            glUseProgram(0);
            let _: () = msg_send![&context, flushBuffer];
        }
    }
}

#[derive(Default)]
struct AppDelegateIvars {
    state: OnceCell<AppState>,
}

struct AppState {
    window: Retained<Object>,
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
                defer:false];
            let _: () = msg_send![&window, setTitle:ns_string!("OpenGL Triangle")];
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
                let _: () = msg_send![&window, setFrame:centered_frame, display:true];
            }
            let _: () = msg_send![&window, setMinSize:NSSize::new(480.0, 360.0)];

            let attributes = [
                NS_OPENGL_PFA_OPENGL_PROFILE,
                NS_OPENGL_PROFILE_VERSION_4_1_CORE,
                NS_OPENGL_PFA_COLOR_SIZE,
                24,
                NS_OPENGL_PFA_ALPHA_SIZE,
                8,
                NS_OPENGL_PFA_DOUBLE_BUFFER,
                NS_OPENGL_PFA_ACCELERATED,
                0,
            ];
            let pixel_format: Allocated<Object> = msg_send![class!(NSOpenGLPixelFormat), alloc];
            let pixel_format: Option<Retained<Object>> =
                msg_send![pixel_format, initWithAttributes:attributes.as_ptr()];
            let Some(pixel_format) = pixel_format else {
                eprintln!("Could not create an OpenGL 4.1 Core pixel format");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            };

            let content_view: Option<Retained<Object>> = msg_send![&window, contentView];
            let Some(content_view) = content_view else {
                eprintln!("Window has no content view");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            };
            let bounds: NSRect = msg_send![&content_view, bounds];
            let renderer: Allocated<RendererView> = msg_send![RendererView::class(), alloc];
            let renderer: Option<Retained<RendererView>> = msg_send![renderer,
                initWithFrame:bounds,
                pixelFormat:&*pixel_format];
            let Some(renderer) = renderer else {
                eprintln!("Could not create the OpenGL renderer view");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            };
            let _: () = msg_send![&renderer, setWantsBestResolutionOpenGLSurface:true];
            let _: () = msg_send![&renderer,
                setAutoresizingMask:NS_VIEW_WIDTH_SIZABLE | NS_VIEW_HEIGHT_SIZABLE];
            let _: () = msg_send![&window, setContentView:&*renderer];

            if self.ivars().state.set(AppState { window }).is_err() {
                eprintln!("Application delegate was already initialized");
                let _: () = msg_send![NSApp, terminate:null::<Object>()];
                return;
            }

            let _: Bool =
                msg_send![NSApp, setActivationPolicy:NS_APPLICATION_ACTIVATION_POLICY_REGULAR];
            let _: () = msg_send![NSApp, activateIgnoringOtherApps:true];
            let state = self.ivars().state.get().unwrap();
            let _: () = msg_send![&state.window, makeKeyAndOrderFront:null::<Object>()];
        }
    }
}

fn main() {
    let _ = RendererView::class();
    let _ = AppDelegate::class();

    autoreleasepool(|_| unsafe {
        let app: Retained<Object> = msg_send![class!(NSApplication), sharedApplication];
        let delegate: Retained<AppDelegate> = msg_send![class!(AppDelegate), new];
        let _: () = msg_send![&app, setDelegate:&*delegate];
        let _: () = msg_send![&app, run];
    });
}
