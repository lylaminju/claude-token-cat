import Foundation
import Combine

// MARK: - Token Usage Manager

/// Tracks Claude API token usage within a 5-hour session window.
/// Currently uses mock data; will be replaced with real API polling later.
final class TokenUsageManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var tokensUsed: Int = 0
    @Published private(set) var tokenLimit: Int = 300_000
    @Published private(set) var sessionStartDate: Date? = nil
    @Published private(set) var isSessionActive: Bool = false

    /// Usage as 0.0–1.0
    var usageRatio: Double {
        guard tokenLimit > 0 else { return 0 }
        return min(Double(tokensUsed) / Double(tokenLimit), 1.0)
    }

    /// Usage as percentage 0–100
    var usagePercent: Int {
        Int(usageRatio * 100)
    }

    /// Current cat state based on usage
    var catState: CatState {
        guard isSessionActive else { return .idle }
        switch usagePercent {
        case 0..<40:    return .running
        case 40..<80:   return .walking
        case 80..<100:  return .tired
        default:        return .sleeping
        }
    }

    /// Time remaining in current session, nil if no session
    var timeRemaining: TimeInterval? {
        guard let start = sessionStartDate else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let remaining = sessionDuration - elapsed
        return max(remaining, 0)
    }

    /// Formatted time remaining string
    var timeRemainingFormatted: String {
        guard let remaining = timeRemaining else { return "No active session" }
        if remaining <= 0 { return "Session reset" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return "\(hours)h \(minutes)m remaining"
    }

    // MARK: - Configuration

    static let sessionDuration: TimeInterval = 5 * 60 * 60  // 5 hours
    private let sessionDuration = TokenUsageManager.sessionDuration
    private let pollInterval: TimeInterval = 5 * 60  // 5 minutes

    // MARK: - Timers

    private var pollTimer: Timer?
    private var sessionResetTimer: Timer?

    // MARK: - Init

    init() {
        // Start with mock data for prototype
        startMockSession()
    }

    deinit {
        pollTimer?.invalidate()
        sessionResetTimer?.invalidate()
    }

    // MARK: - Mock Data

    /// Starts a mock session with simulated usage for testing.
    func startMockSession() {
        sessionStartDate = Date().addingTimeInterval(-2 * 60 * 60)  // 2 hours ago
        isSessionActive = true
        tokensUsed = 135_000    // ~45% of 300k
        tokenLimit = 300_000

        scheduleSessionReset()
    }

    /// Cycle through different usage levels for testing animations.
    func cycleMockUsage() {
        let levels = [0, 30, 45, 65, 85, 95, 100]
        let currentIndex = levels.firstIndex(where: { $0 >= usagePercent }) ?? 0
        let nextIndex = (currentIndex + 1) % levels.count
        let nextPercent = levels[nextIndex]

        if nextPercent == 0 {
            isSessionActive = false
            tokensUsed = 0
            sessionStartDate = nil
        } else {
            isSessionActive = true
            if sessionStartDate == nil {
                sessionStartDate = Date().addingTimeInterval(-2 * 60 * 60)
            }
            tokensUsed = Int(Double(tokenLimit) * Double(nextPercent) / 100.0)
        }
    }

    // MARK: - Session Management

    func resetSession() {
        tokensUsed = 0
        sessionStartDate = nil
        isSessionActive = false
        pollTimer?.invalidate()
        sessionResetTimer?.invalidate()
    }

    private func scheduleSessionReset() {
        guard let remaining = timeRemaining, remaining > 0 else { return }
        sessionResetTimer?.invalidate()
        sessionResetTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.resetSession()
        }
    }

    // MARK: - API Polling (placeholder)

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
    }

    private func fetchUsage() {
        // TODO: Replace with real Claude API call
        // For now, slowly increment mock usage
        let increment = Int.random(in: 500...2000)
        tokensUsed = min(tokensUsed + increment, tokenLimit)
    }
}
