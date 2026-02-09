import AppKit
import SwiftUI
import Combine

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var animationTimer: Timer?
    private var currentFrameIndex = 0
    private var currentFrames: [NSImage] = []
    private var currentState: CatState = .idle

    let usageManager = TokenUsageManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        observeUsageChanges()
        switchToState(.idle)
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(CatSpriteRenderer.spriteWidth))

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            // Initial image will be set by switchToState
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 300)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(usageManager: usageManager)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Bring popover to front
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Animation

    private func observeUsageChanges() {
        // Watch for state changes from the usage manager
        usageManager.$usagePercent
            .combineLatest(usageManager.$isSessionActive)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                let newState = self.usageManager.catState
                if newState != self.currentState {
                    self.switchToState(newState)
                }
            }
            .store(in: &cancellables)

        // Watch for animation pause toggle
        usageManager.$animationEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.switchToState(self.currentState)
            }
            .store(in: &cancellables)
    }

    private func switchToState(_ state: CatState) {
        currentState = state
        currentFrames = CatSpriteRenderer.frames(for: state)
        currentFrameIndex = 0

        // Set first frame immediately
        if let first = currentFrames.first {
            statusItem.button?.image = first
        }

        // Restart animation timer (only when not paused)
        animationTimer?.invalidate()
        animationTimer = nil

        guard usageManager.animationEnabled else { return }

        let interval = animationInterval(for: state)
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
    }

    private func advanceFrame() {
        guard !currentFrames.isEmpty else { return }
        currentFrameIndex = (currentFrameIndex + 1) % currentFrames.count
        statusItem.button?.image = currentFrames[currentFrameIndex]
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
