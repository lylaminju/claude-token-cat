import AppKit
import SwiftUI
import Combine

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var hostingView: NSHostingView<PopoverView>!
    private var animationTimer: Timer?
    private var currentFrameIndex = 0
    private var currentFrames: [NSImage] = []
    private var currentState: CatState = .idle

    let usageManager = TokenUsageManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        observeUsageChanges()
        switchToState(.idle)
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(showMenu)
            button.target = self
        }

        // Use NSMenu with a custom view instead of NSPopover.
        // An open NSMenu keeps the menu bar visible even when auto-hide is enabled.
        menu = NSMenu()
        menu.delegate = self

        hostingView = NSHostingView(rootView: PopoverView(usageManager: usageManager))

        let menuItem = NSMenuItem()
        menuItem.view = hostingView
        menu.addItem(menuItem)
    }

    @objc private func showMenu() {
        guard let button = statusItem.button,
              let window = button.window else { return }

        // Convert button position to screen coordinates
        let buttonRect = window.convertToScreen(button.convert(button.bounds, to: nil))

        // Center the menu horizontally under the cat icon, with a small gap below the menu bar
        let menuWidth: CGFloat = 280
        let x = buttonRect.midX - menuWidth / 2
        let y = buttonRect.minY - 10
        menu.popUp(positioning: nil, at: NSPoint(x: x, y: y), in: nil)
    }

    // MARK: - Animation

    private func observeUsageChanges() {
        // Watch for state changes from the usage manager
        // Use DispatchQueue.main (not RunLoop.main) so updates fire during NSMenu event tracking
        usageManager.$usagePercent
            .combineLatest(usageManager.$isSessionActive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                let newState = self.usageManager.catState
                if newState != self.currentState {
                    self.switchToState(newState)
                }
                self.updatePercentageDisplay()
            }
            .store(in: &cancellables)

        // Watch for animation pause toggle
        usageManager.$animationEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.switchToState(self.currentState)
            }
            .store(in: &cancellables)

        // Watch for percentage display toggle
        usageManager.$showPercentageInMenuBar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePercentageDisplay()
            }
            .store(in: &cancellables)
    }

    private func switchToState(_ state: CatState) {
        currentState = state
        currentFrames = CatSpriteRenderer.frames(for: state)
        currentFrameIndex = 0

        // Set first frame immediately
        currentFrameIndex = 0
        updateStatusImage()

        // Restart animation timer (only when not paused)
        animationTimer?.invalidate()
        animationTimer = nil

        guard usageManager.animationEnabled else { return }

        let interval = animationInterval(for: state)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
        // .common includes event-tracking mode so the animation keeps running while the menu is open
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func advanceFrame() {
        guard !currentFrames.isEmpty else { return }
        currentFrameIndex = (currentFrameIndex + 1) % currentFrames.count
        updateStatusImage()
    }

    private func updatePercentageDisplay() {
        updateStatusImage()
    }

    /// Composites percentage text into the cat image so the cat never shifts position when toggling.
    private func updateStatusImage() {
        guard !currentFrames.isEmpty else { return }
        let catFrame = currentFrames[currentFrameIndex]

        if usageManager.showPercentageInMenuBar && usageManager.isSessionActive {
            statusItem.button?.image = compositeImage(catFrame: catFrame, text: "\(Int(usageManager.usagePercent))%")
        } else {
            statusItem.button?.image = catFrame
        }
    }

    private func compositeImage(catFrame: NSImage, text: String) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let spacing: CGFloat = 6
        let totalWidth = textSize.width + spacing + catFrame.size.width
        let height = max(catFrame.size.height, textSize.height)

        let composite = NSImage(size: NSSize(width: totalWidth, height: height))
        composite.lockFocus()
        (text as NSString).draw(
            at: NSPoint(x: 0, y: (height - textSize.height) / 2),
            withAttributes: attrs
        )
        catFrame.draw(
            in: NSRect(x: textSize.width + spacing, y: (height - catFrame.size.height) / 2,
                       width: catFrame.size.width, height: catFrame.size.height),
            from: .zero, operation: .sourceOver, fraction: 1.0
        )
        composite.unlockFocus()
        composite.isTemplate = true
        return composite
    }

    /// Different states animate at different speeds.
    private func animationInterval(for state: CatState) -> TimeInterval {
        switch state {
        case .idle:     return 0.35   // Gentle tail wag
        case .jumping:  return 0.15   // Fast jumping
        case .walking:  return 0.4    // Moderate walk
        case .tired:    return 0.8    // Slow yawning
        case .sleeping: return 1.2    // Slow ZZ pulse
        }
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Recompute size each time the menu opens so dynamic content is fully visible
        let fitting = hostingView.fittingSize
        hostingView.setFrameSize(NSSize(width: 280, height: fitting.height))

    }

    func menuDidClose(_ menu: NSMenu) {
        NotificationCenter.default.post(name: .popoverDidClose, object: nil)
    }
}
