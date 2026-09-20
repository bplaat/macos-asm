import Cocoa
import OpenGL.GL3

private struct Vertex {
    let positionX: GLfloat
    let positionY: GLfloat
    let red: GLfloat
    let green: GLfloat
    let blue: GLfloat
    let alpha: GLfloat
}

private let vertices = [
    Vertex(positionX: 0.0, positionY: 0.75, red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0),
    Vertex(positionX: -0.7, positionY: -0.6, red: 0.1, green: 1.0, blue: 0.2, alpha: 1.0),
    Vertex(positionX: 0.7, positionY: -0.6, red: 0.1, green: 0.3, blue: 1.0, alpha: 1.0),
]

private func openGLString(_ name: GLenum) -> String {
    guard let value = glGetString(name) else {
        return "unknown"
    }
    let characters = UnsafeRawPointer(value).assumingMemoryBound(to: CChar.self)
    return String(cString: characters)
}

private func loadShader(name: String, extension extensionName: String) -> String? {
    guard let url = Bundle.main.url(forResource: name, withExtension: extensionName) else {
        NSLog("Could not find OpenGL shader resource: \(name).\(extensionName)")
        return nil
    }
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        NSLog("Could not load OpenGL shader resource: \(error)")
        return nil
    }
}

private func compileShader(type: GLenum, source: String) -> GLuint {
    let shader = glCreateShader(type)
    source.withCString { sourceCharacters in
        var sourcePointer: UnsafePointer<GLchar>? = sourceCharacters
        glShaderSource(shader, 1, &sourcePointer, nil)
    }
    glCompileShader(shader)

    var compiled = GLint(GL_FALSE)
    glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &compiled)
    if compiled == GL_TRUE {
        return shader
    }

    var logLength: GLint = 0
    glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
    var log = [GLchar](repeating: 0, count: max(Int(logLength), 1))
    glGetShaderInfoLog(shader, GLsizei(log.count), nil, &log)
    log.withUnsafeBufferPointer { buffer in
        NSLog("Could not compile OpenGL shader: %s", buffer.baseAddress!)
    }
    glDeleteShader(shader)
    return 0
}

private func createProgram(vertexSource: String, fragmentSource: String) -> GLuint {
    let vertexShader = compileShader(type: GLenum(GL_VERTEX_SHADER), source: vertexSource)
    guard vertexShader != 0 else {
        return 0
    }

    let fragmentShader = compileShader(type: GLenum(GL_FRAGMENT_SHADER), source: fragmentSource)
    guard fragmentShader != 0 else {
        glDeleteShader(vertexShader)
        return 0
    }

    let program = glCreateProgram()
    glAttachShader(program, vertexShader)
    glAttachShader(program, fragmentShader)
    glLinkProgram(program)
    glDeleteShader(vertexShader)
    glDeleteShader(fragmentShader)

    var linked = GLint(GL_FALSE)
    glGetProgramiv(program, GLenum(GL_LINK_STATUS), &linked)
    if linked == GL_TRUE {
        return program
    }

    var logLength: GLint = 0
    glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength)
    var log = [GLchar](repeating: 0, count: max(Int(logLength), 1))
    glGetProgramInfoLog(program, GLsizei(log.count), nil, &log)
    log.withUnsafeBufferPointer { buffer in
        NSLog("Could not link OpenGL program: %s", buffer.baseAddress!)
    }
    glDeleteProgram(program)
    return 0
}

private final class RendererView: NSOpenGLView {
    private var program: GLuint = 0
    private var vertexArray: GLuint = 0
    private var vertexBuffer: GLuint = 0

    override func prepareOpenGL() {
        super.prepareOpenGL()
        openGLContext?.makeCurrentContext()

        NSLog("OpenGL version: \(openGLString(GLenum(GL_VERSION))), device: \(openGLString(GLenum(GL_RENDERER)))")

        var swapInterval: GLint = 1
        openGLContext?.setValues(&swapInterval, for: .swapInterval)

        guard let vertexSource = loadShader(name: "shader", extension: "vert"),
              let fragmentSource = loadShader(name: "shader", extension: "frag")
        else {
            NSApp.terminate(nil)
            return
        }

        program = createProgram(vertexSource: vertexSource, fragmentSource: fragmentSource)
        guard program != 0 else {
            NSApp.terminate(nil)
            return
        }

        glGenVertexArrays(1, &vertexArray)
        glBindVertexArray(vertexArray)

        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        vertices.withUnsafeBufferPointer { buffer in
            glBufferData(
                GLenum(GL_ARRAY_BUFFER),
                buffer.count * MemoryLayout<Vertex>.stride,
                buffer.baseAddress,
                GLenum(GL_STATIC_DRAW)
            )
        }

        glEnableVertexAttribArray(0)
        glVertexAttribPointer(
            0,
            2,
            GLenum(GL_FLOAT),
            GLboolean(GL_FALSE),
            GLsizei(MemoryLayout<Vertex>.stride),
            nil
        )
        glEnableVertexAttribArray(1)
        glVertexAttribPointer(
            1,
            4,
            GLenum(GL_FLOAT),
            GLboolean(GL_FALSE),
            GLsizei(MemoryLayout<Vertex>.stride),
            UnsafeRawPointer(bitPattern: 2 * MemoryLayout<GLfloat>.stride)
        )

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        glClearColor(0.015, 0.02, 0.04, 1.0)
    }

    override func reshape() {
        super.reshape()
        openGLContext?.makeCurrentContext()
        let backingBounds = convertToBacking(bounds)
        glViewport(0, 0, GLsizei(backingBounds.width), GLsizei(backingBounds.height))
    }

    override func draw(_ dirtyRect: NSRect) {
        openGLContext?.makeCurrentContext()
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        glUseProgram(program)
        glBindVertexArray(vertexArray)
        glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(vertices.count))
        glBindVertexArray(0)
        glUseProgram(0)
        openGLContext?.flushBuffer()
    }

    deinit {
        openGLContext?.makeCurrentContext()
        if vertexBuffer != 0 {
            glDeleteBuffers(1, &vertexBuffer)
        }
        if vertexArray != 0 {
            glDeleteVertexArrays(1, &vertexArray)
        }
        if program != 0 {
            glDeleteProgram(program)
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Triangle",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1024, height: 768),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenGL Triangle"
        window.appearance = NSAppearance(named: .darkAqua)
        let windowX = (window.screen!.frame.width - window.frame.width) / 2
        let windowY = (window.screen!.frame.height - window.frame.height) / 2
        window.setFrame(NSMakeRect(windowX, windowY, window.frame.width, window.frame.height), display: true)
        window.minSize = NSSize(width: 480, height: 360)

        var attributes: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAOpenGLProfile),
            UInt32(NSOpenGLProfileVersion4_1Core),
            UInt32(NSOpenGLPFAColorSize),
            24,
            UInt32(NSOpenGLPFAAlphaSize),
            8,
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAAccelerated),
            0,
        ]
        guard let pixelFormat = NSOpenGLPixelFormat(attributes: &attributes),
              let rendererView = RendererView(frame: window.contentView!.bounds, pixelFormat: pixelFormat)
        else {
            NSLog("Could not create an OpenGL 4.1 Core renderer view")
            NSApp.terminate(nil)
            return
        }
        rendererView.wantsBestResolutionOpenGLSurface = true
        rendererView.autoresizingMask = [.width, .height]
        window.contentView = rendererView

        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
