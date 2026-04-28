import AppKit
import SwiftData
import SwiftUI

/// Hosts the Breathing History panel in a translucent (liquid-glass) window.
/// The view itself paints the `.ultraThinMaterial` background; the window only needs
/// to stay transparent and let the title bar overlay the content.
@MainActor
final class BreathingHistoryWindowController {
    private var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = BreathingHistoryView(appState: appState)
            .modelContainer(appState.modelContainer)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Breathing history"
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false

        // Initial size — wide enough for the heatmap and patterns to breathe.
        let initialSize = NSSize(width: 540, height: 760)
        window.setContentSize(initialSize)
        window.minSize = NSSize(width: 460, height: 480)
        window.center()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
