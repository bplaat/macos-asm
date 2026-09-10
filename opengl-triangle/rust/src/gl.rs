use std::ffi::{c_char, c_void};

pub(crate) type GLenum = u32;
pub(crate) type GLuint = u32;
pub(crate) type GLint = i32;
pub(crate) type GLsizei = i32;
pub(crate) type GLsizeiptr = isize;
pub(crate) type GLboolean = u8;
pub(crate) type GLbitfield = u32;
pub(crate) type GLfloat = f32;

pub(crate) const GL_FALSE: GLint = 0;
pub(crate) const GL_TRUE: GLint = 1;
pub(crate) const GL_VERSION: GLenum = 0x1f02;
pub(crate) const GL_RENDERER: GLenum = 0x1f01;
pub(crate) const GL_VERTEX_SHADER: GLenum = 0x8b31;
pub(crate) const GL_FRAGMENT_SHADER: GLenum = 0x8b30;
pub(crate) const GL_COMPILE_STATUS: GLenum = 0x8b81;
pub(crate) const GL_LINK_STATUS: GLenum = 0x8b82;
pub(crate) const GL_INFO_LOG_LENGTH: GLenum = 0x8b84;
pub(crate) const GL_ARRAY_BUFFER: GLenum = 0x8892;
pub(crate) const GL_STATIC_DRAW: GLenum = 0x88e4;
pub(crate) const GL_FLOAT: GLenum = 0x1406;
pub(crate) const GL_COLOR_BUFFER_BIT: GLbitfield = 0x00004000;
pub(crate) const GL_TRIANGLES: GLenum = 0x0004;

#[link(name = "OpenGL", kind = "framework")]
unsafe extern "C" {
    pub(crate) fn glGetString(name: GLenum) -> *const u8;
    pub(crate) fn glCreateShader(shader_type: GLenum) -> GLuint;
    pub(crate) fn glShaderSource(
        shader: GLuint,
        count: GLsizei,
        strings: *const *const c_char,
        lengths: *const GLint,
    );
    pub(crate) fn glCompileShader(shader: GLuint);
    pub(crate) fn glGetShaderiv(shader: GLuint, parameter: GLenum, value: *mut GLint);
    pub(crate) fn glGetShaderInfoLog(
        shader: GLuint,
        buffer_size: GLsizei,
        length: *mut GLsizei,
        log: *mut c_char,
    );
    pub(crate) fn glDeleteShader(shader: GLuint);
    pub(crate) fn glCreateProgram() -> GLuint;
    pub(crate) fn glAttachShader(program: GLuint, shader: GLuint);
    pub(crate) fn glLinkProgram(program: GLuint);
    pub(crate) fn glGetProgramiv(program: GLuint, parameter: GLenum, value: *mut GLint);
    pub(crate) fn glGetProgramInfoLog(
        program: GLuint,
        buffer_size: GLsizei,
        length: *mut GLsizei,
        log: *mut c_char,
    );
    pub(crate) fn glDeleteProgram(program: GLuint);
    pub(crate) fn glGenVertexArrays(count: GLsizei, arrays: *mut GLuint);
    pub(crate) fn glBindVertexArray(array: GLuint);
    pub(crate) fn glDeleteVertexArrays(count: GLsizei, arrays: *const GLuint);
    pub(crate) fn glGenBuffers(count: GLsizei, buffers: *mut GLuint);
    pub(crate) fn glBindBuffer(target: GLenum, buffer: GLuint);
    pub(crate) fn glBufferData(
        target: GLenum,
        size: GLsizeiptr,
        data: *const c_void,
        usage: GLenum,
    );
    pub(crate) fn glDeleteBuffers(count: GLsizei, buffers: *const GLuint);
    pub(crate) fn glEnableVertexAttribArray(index: GLuint);
    pub(crate) fn glVertexAttribPointer(
        index: GLuint,
        size: GLint,
        data_type: GLenum,
        normalized: GLboolean,
        stride: GLsizei,
        pointer: *const c_void,
    );
    pub(crate) fn glClearColor(red: GLfloat, green: GLfloat, blue: GLfloat, alpha: GLfloat);
    pub(crate) fn glViewport(x: GLint, y: GLint, width: GLsizei, height: GLsizei);
    pub(crate) fn glClear(mask: GLbitfield);
    pub(crate) fn glUseProgram(program: GLuint);
    pub(crate) fn glDrawArrays(mode: GLenum, first: GLint, count: GLsizei);
}
