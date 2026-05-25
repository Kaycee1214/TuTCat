import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        createPetWindow()
    }

    private func createPetWindow() {
        let size = NSSize(width: 140, height: 140)
        let rect = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.isMovableByWindowBackground = true
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let petView = PetView(frame: rect)
        window.contentView = petView

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.minY - 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.orderFrontRegardless()
        petWindow = window

        print("宠物窗口已创建: \(window.frame)")
    }
}

@main
struct DesktopPetMain {
    static func main() {
        autoreleasepool {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.run()
        }
    }
}
