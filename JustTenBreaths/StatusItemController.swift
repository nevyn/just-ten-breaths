import AppKit
import SwiftUI

@MainActor
final class StatusItemController {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var animationTimer: Timer?
    private var animationStartTime: Date?
    private let appState: AppState
    private let settingsWindowController: SettingsWindowController
    private let breathingWindowController = BreathingWindowController()
    private let breathingHistoryWindowController: BreathingHistoryWindowController
    private let onboardingWindowController: OnboardingWindowController

    // Fixed icon size to prevent jumping
    private let iconSize: CGFloat = 22

    init(appState: AppState, onboardingWindowController: OnboardingWindowController) {
        self.appState = appState
        self.settingsWindowController = SettingsWindowController(appState: appState)
        self.breathingHistoryWindowController = BreathingHistoryWindowController(appState: appState)
        self.onboardingWindowController = onboardingWindowController
        setupStatusItem()
        
        breathingWindowController.onDismiss = { [weak self] in
            guard let self else { return }
            self.statusItem?.button?.highlight(false)
            self.update() // Restore menu now that the breathing window is gone
        }

        breathingWindowController.onSessionDone = { [weak self] sessionStart in
            self?.appState.markDone(sessionStart: sessionStart, sessionEnd: Date())
        }
    }
    
    private func setupStatusItem() {
        // Use fixed length to prevent jumping during animation
        statusItem = NSStatusBar.system.statusItem(withLength: 24)
        
        updateIcon(animated: false)
        
        // Build menu
        let menu = NSMenu()
        
        // Done item (initially hidden)
        let doneItem = NSMenuItem(title: "Done", action: #selector(doneClicked), keyEquivalent: "d")
        doneItem.target = self
        doneItem.tag = 1
        doneItem.isHidden = true
        doneItem.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Done")
        menu.addItem(doneItem)
        
        // Primed toggle
        let primedItem = NSMenuItem(title: "Remind me to Breathe", action: #selector(togglePrimed), keyEquivalent: "r")
        primedItem.target = self
        primedItem.tag = 2
        primedItem.state = appState.isPrimed ? .on : .off
        primedItem.image = NSImage(systemSymbolName: "bell", accessibilityDescription: "Reminder")
        menu.addItem(primedItem)
        
        // Breathe now
        let breatheNowItem = NSMenuItem(title: "Breathe now…", action: #selector(breatheNowClicked), keyEquivalent: "b")
        breatheNowItem.target = self
        breatheNowItem.image = NSImage(systemSymbolName: "wind", accessibilityDescription: "Breathe")
        menu.addItem(breatheNowItem)

        // Breathing history
        let historyItem = NSMenuItem(title: "Breathing history…", action: #selector(openBreathingHistory), keyEquivalent: "")
        historyItem.target = self
        historyItem.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "History")
        menu.addItem(historyItem)

        let separator1 = NSMenuItem.separator()
        separator1.tag = 3
        menu.addItem(separator1)
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)
        
        // About
        let aboutItem = NSMenuItem(title: "About just ten breaths", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        menu.addItem(aboutItem)

        #if DEBUG
        menu.addItem(NSMenuItem.separator())
        
        let onboardingItem = NSMenuItem(title: "Onboarding…", action: #selector(openOnboarding), keyEquivalent: "o")
        onboardingItem.target = self
        onboardingItem.image = NSImage(systemSymbolName: "airplane.arrival", accessibilityDescription: "Onboarding")
        menu.addItem(onboardingItem)

        let testItem = NSMenuItem(title: "Test Animation", action: #selector(testAnimation), keyEquivalent: "t")
        testItem.target = self
        testItem.tag = 100
        testItem.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Test")
        menu.addItem(testItem)
        #endif
        
        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit just ten breaths", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Quit")
        menu.addItem(quitItem)
        
        self.menu = menu
        statusItem?.menu = menu
    }
    
    func update() {
        // Update menu item state (tags: 1=done, 2=primed, 3=separator)
        if let menu {
            if let doneItem = menu.item(withTag: 1) {
                doneItem.isHidden = !appState.isBreathingTime
            }
            if let primedItem = menu.item(withTag: 2) {
                primedItem.state = appState.isPrimed ? .on : .off
            }
            #if DEBUG
            if let testItem = menu.item(withTag: 100) {
                testItem.title = appState.isBreathingTime ? "Stop Test Animation" : "Test Animation"
            }
            #endif
        }
        
        // Swap between menu and breathing-window click handling.
        // Stay in action mode while breathing OR while the breathing window is
        // still visible (markDone clears isBreathingTime before the window closes).
        if appState.isBreathingTime || breathingWindowController.isVisible {
            // Remove the menu so clicks go to our action handler
            statusItem?.menu = nil
            statusItem?.button?.action = #selector(statusItemClicked)
            statusItem?.button?.target = self
        } else {
            // Restore normal menu behavior
            statusItem?.menu = menu
            statusItem?.button?.action = nil
            statusItem?.button?.target = nil
        }
        
        // Handle animation state
        if appState.isBreathingTime && animationTimer == nil {
            startAnimation()
            // Auto-open the breathing window if the user prefers immediate breathing
            if appState.settings.autoOpenBreathingWindow && !breathingWindowController.isVisible {
                showBreathingWindow()
                appState.markDone()
            }
        } else if !appState.isBreathingTime && animationTimer != nil {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        animationStartTime = Date()
        updateIcon(animated: true)
        
        // 30fps for smooth animation
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateIcon(animated: true)
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationStartTime = nil
        updateIcon(animated: false)
    }
    
    private func updateIcon(animated: Bool) {
        guard let button = statusItem?.button else { return }
        button.image = makeIcon(animated: animated)
    }
    
    private func makeIcon(animated: Bool) -> NSImage {
        var rotation: CGFloat = 0
        var scaleAmount: CGFloat = 1.0
        var tintColor: NSColor? = nil
        
        if animated, let startTime = animationStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let fadeIn = min(1.0, elapsed / 0.8)
            
            // Burst-rest jiggle: 2-3 quick shakes every 2 seconds
            let period = 2.0
            let cycle = elapsed.truncatingRemainder(dividingBy: period)
            let burstDuration = 0.5
            
            var colorAmount: CGFloat = 0
            
            if cycle < burstDuration {
                let damping = 1.0 - cycle / burstDuration
                rotation = 25 * damping * sin(cycle * 30)
                scaleAmount = 1.0 + 0.15 * damping * abs(sin(cycle * 30))
                colorAmount = fadeIn
            } else {
                rotation = 0
                scaleAmount = 1.0
                let restT = (cycle - burstDuration) / (period - burstDuration)
                colorAmount = fadeIn * max(0.0, 1.0 - restT)
            }
            
            // When fully faded, leave tintColor nil so the icon returns to template mode
            if colorAmount > 0.01 {
                let cycleIndex = Int(elapsed / period)
                let hue = CGFloat((cycleIndex * 137) % 360) / 360.0
                tintColor = NSColor(calibratedHue: hue, saturation: 0.7, brightness: 0.85, alpha: colorAmount)
            }
        }
        
        let image = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: false) { [self] rect in
            self.drawIcon(in: rect, rotation: rotation, scale: scaleAmount, tintColor: tintColor)
            return true
        }
        
        image.isTemplate = (tintColor == nil)
        
        return image
    }
    
    private func drawIcon(in rect: NSRect, rotation: CGFloat, scale: CGFloat, tintColor: NSColor?) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        guard let symbolImage = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "just ten breaths")?
            .withSymbolConfiguration(config) else { return }
        
        let symbolSize = symbolImage.size
        let centerX = rect.midX
        let centerY = rect.midY
        
        let drawRect = NSRect(
            x: centerX - symbolSize.width / 2,
            y: centerY - symbolSize.height / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )
        
        context.saveGState()
        
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: rotation * .pi / 180)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -centerX, y: -centerY)
        
        if let tintColor, tintColor.alphaComponent > 0 {
            let colorAmount = tintColor.alphaComponent
            
            // Neutral gray underlay — works on both light and dark menu bars
            if colorAmount < 1.0 {
                let grayColor = NSColor(white: 0.55, alpha: 1.0 - colorAmount)
                drawTintedSymbol(symbolImage, in: drawRect, tint: grayColor)
            }
            
            drawTintedSymbol(symbolImage, in: drawRect, tint: tintColor)
        } else {
            // Grayscale fallback (template mode handles the actual tinting)
            drawTintedSymbol(symbolImage, in: drawRect, tint: NSColor(white: 0.55, alpha: 1.0))
        }
        
        context.restoreGState()
    }
    
    private func drawTintedSymbol(_ symbol: NSImage, in rect: NSRect, tint: NSColor) {
        // Draw symbol and apply tint using compositing
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw the symbol
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        
        // Apply tint color using sourceAtop blend mode
        context.saveGState()
        context.setBlendMode(.sourceAtop)
        tint.setFill()
        context.fill(rect.insetBy(dx: -5, dy: -5)) // Slightly larger to catch edges
        context.restoreGState()
    }
    
    // MARK: - Actions
    
    @objc private func statusItemClicked() {
        if breathingWindowController.isVisible {
            breathingWindowController.dismiss()
        } else {
            showBreathingWindow()
            // Mark done immediately so the menu bar icon stops animating
            appState.markDone()
            update()
        }
    }
    
    private func showBreathingWindow() {
        statusItem?.button?.highlight(true)
        breathingWindowController.show(
            below: statusItem?.button,
            cadence: appState.settings.breathingCadence,
            appearanceStyle: appState.settings.appearanceStyle,
            isFullscreen: appState.settings.prefersFullscreenBreathing,
            onCadenceChanged: { [weak self] newCadence in
                self?.appState.settings.breathingCadence = newCadence
            },
            onFullscreenChanged: { [weak self] fullscreen in
                self?.appState.settings.prefersFullscreenBreathing = fullscreen
            }
        )
    }
    
    @objc private func breatheNowClicked() {
        showBreathingWindow()
        update() // Switch to action mode so clicking the icon dismisses the window
    }
    
    @objc private func doneClicked() {
        appState.markDone()
        update()
    }
    
    @objc private func togglePrimed() {
        appState.togglePrimed()
        update()
    }
    
    @objc private func openOnboarding() {
        onboardingWindowController.show()
    }

    
    @objc private func openSettings() {
        settingsWindowController.showSettings()
    }

    @objc private func openBreathingHistory() {
        breathingHistoryWindowController.show()
    }
    
    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let url = URL(string: "https://nevyn.github.io/just-ten-breaths/")!
        let credits = NSMutableAttributedString(string: "Read more: ")
        credits.append(NSAttributedString(string: "nevyn.github.io/just-ten-breaths", attributes: [
            .link: url,
            .foregroundColor: NSColor.linkColor,
        ]))
        NSApp.orderFrontStandardAboutPanel(options: [
            NSApplication.AboutPanelOptionKey.credits: credits,
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 Nevyn Bengtsson, hello@nevyn.dev",
        ])
    }
    
    @objc private func testAnimation() {
        appState.isBreathingTime.toggle()
        update()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
