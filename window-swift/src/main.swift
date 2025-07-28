import Cocoa

// MARK: CanvasView
class CanvasView : NSView {
    override func draw(_ dirtyRect: NSRect) {
        let text = "Hello macOS!"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 48),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let rect = NSRect(x: (self.frame.width - size.width) / 2,
            y: (self.frame.height - size.height) / 2,
            width: size.width,
            height: size.height)
        text.draw(in: rect, withAttributes: attributes)
    }
}

// MARK: AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu
        let menubar = NSMenu()
        NSApp.mainMenu = menubar

        let menuBarItem = NSMenuItem()
        menubar.addItem(menuBarItem)

        let appMenu = NSMenu()
        menuBarItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "About BassieTest", action: #selector(AppDelegate.openAbout(_:)), keyEquivalent: "a"))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit BassieTest", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Create window
        let window = NSWindow(contentRect: NSMakeRect(0, 0, 1024, 768),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "BassieTest"
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        let windowX = (window.screen!.frame.width - window.frame.width) / 2
        let windowY = (window.screen!.frame.height - window.frame.height) / 2
        window.setFrame(NSMakeRect(windowX, windowY, window.frame.width, window.frame.height), display: true)
        window.minSize = NSMakeSize(320, 240)
        window.backgroundColor = NSColor(red: 0x05 / 255.0, green: 0x44 / 255.0, blue: 0x5e / 255.0, alpha: 1)
        window.setFrameUsingName("window")

        // Create canvas
        window.contentView = CanvasView()

        // Show window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @objc
    func openAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
