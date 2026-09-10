import Cocoa
import MetalKit

private let vertices = [
    Vertex(position: SIMD2(0.0, 0.75), color: SIMD4(1.0, 0.1, 0.1, 1.0)),
    Vertex(position: SIMD2(-0.7, -0.6), color: SIMD4(0.1, 1.0, 0.2, 1.0)),
    Vertex(position: SIMD2(0.7, -0.6), color: SIMD4(0.1, 0.3, 1.0, 1.0)),
]

private final class Renderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    init?(view: MTKView) {
        guard let device = view.device,
              let commandQueue = device.makeCommandQueue(),
              let libraryURL = Bundle.main.url(forResource: "default", withExtension: "metallib")
        else {
            NSLog("Could not initialize Metal")
            return nil
        }

        do {
            let library = try device.makeLibrary(URL: libraryURL)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
            descriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
            descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat

            self.commandQueue = commandQueue
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            NSLog("Could not create Metal pipeline: \(error)")
            return nil
        }

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        _ = view
        _ = size
    }

    func draw(in view: MTKView) {
        guard let renderPass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)
        else {
            return
        }

        commandBuffer.label = "Rainbow Triangle"
        encoder.label = "Triangle Render Pass"
        encoder.setRenderPipelineState(pipelineState)
        vertices.withUnsafeBufferPointer { buffer in
            encoder.setVertexBytes(
                buffer.baseAddress!,
                length: buffer.count * MemoryLayout<Vertex>.stride,
                index: Int(BufferIndexVertices.rawValue)
            )
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var renderer: Renderer?

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
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Triangle"
        window.appearance = NSAppearance(named: .darkAqua)
        let windowX = (window.screen!.frame.width - window.frame.width) / 2
        let windowY = (window.screen!.frame.height - window.frame.height) / 2
        window.setFrame(NSMakeRect(windowX, windowY, window.frame.width, window.frame.height), display: true)
        window.minSize = NSSize(width: 480, height: 360)

        guard let device = MTLCreateSystemDefaultDevice() else {
            NSLog("Metal is not supported on this Mac")
            NSApp.terminate(nil)
            return
        }
        var metalVersion = "2 or earlier"
        if #available(macOS 26.0, *), device.supportsFamily(.metal4) {
            metalVersion = "4"
        } else if #available(macOS 13.0, *), device.supportsFamily(.metal3) {
            metalVersion = "3"
        }
        NSLog("Metal version: \(metalVersion), device: \(device.name)")

        let metalView = MTKView(frame: window.contentView!.bounds, device: device)
        metalView.autoresizingMask = [.width, .height]
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColor(red: 0.015, green: 0.02, blue: 0.04, alpha: 1.0)
        metalView.preferredFramesPerSecond = 60

        guard let renderer = Renderer(view: metalView) else {
            NSApp.terminate(nil)
            return
        }
        metalView.delegate = renderer
        window.contentView = metalView

        self.window = window
        self.renderer = renderer

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
