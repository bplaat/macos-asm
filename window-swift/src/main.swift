import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var label: NSText!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu
        let menubar = NSMenu()
        NSApp.mainMenu = menubar

        let menuBarItem = NSMenuItem()
        menubar.addItem(menuBarItem)

        let appMenu = NSMenu()
        menuBarItem.submenu = appMenu

        let quitMenuItem = NSMenuItem(title: "Quit BassieTest", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitMenuItem)

        // Create window
        window = NSWindow(contentRect: NSMakeRect(0, 0, 1024, 768),
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
        window.delegate = self

        // Create label
        label = NSText(frame: NSMakeRect(0, (window.frame.height - 48) / 2, window.frame.width, 48))
        label.string = "Hello macOS!"
        label.font = NSFont.systemFont(ofSize: 48)
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        window.contentView!.addSubview(label)

        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func windowDidResize(_ notification: Notification) {
        label.frame = NSMakeRect(0, (window.frame.height - 48) / 2, window.frame.width, 48)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
