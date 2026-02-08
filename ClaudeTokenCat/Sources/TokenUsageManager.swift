import Foundation
import Combine

// MARK: - Token Usage Manager

/// Tracks Claude API token usage within a 5-hour session window.
/// Uses real API data from Claude Code's OAuth credentials when available,
/// falls back to mock data otherwise.
final class TokenUsageManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var usagePercent: Double = 0
    @Published private(set) var weeklyUsagePercent: Double = 0
    @Published private(set) var sessionResetDate: Date? = nil
    @Published private(set) var isSessionActive: Bool = false
    @Published private(set) var isUsingMockData: Bool = true
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var lastUpdated: Date? = nil

    // Mock-only state
    @Published private(set) var tokensUsed: Int = 0
    @Published private(set) var tokenLimit: Int = 300_000

    /// Usage as 0.0–1.0 for the progress bar
    var usageRatio: Double {
        min(usagePercent / 100.0, 1.0)
    }

    /// Current cat state based on usage
    var catState: CatState {
        guard isSessionActive else { return .idle }
        let pct = Int(usagePercent)
        switch pct {
        case 0..<40:    return .running
        case 40..<80:   return .walking
        case 80..<100:  return .tired
        default:        return .sleeping
        }
    }

    /// Time remaining in current session
    var timeRemaining: TimeInterval? {
        guard let reset = sessionResetDate else { return nil }
        let remaining = reset.timeIntervalSinceNow
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

    private let pollInterval: TimeInterval = 5 * 60  // 5 minutes

    // MARK: - Timers

    private var pollTimer: Timer?

    // MARK: - Init

    init() {
        if let token = ClaudeCodeCredentials.loadAccessToken() {
            isUsingMockData = false
            startPolling(accessToken: token)
        } else {
            isUsingMockData = true
            startMockSession()
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Real API Polling

    private func startPolling(accessToken: String) {
        // Fetch immediately
        fetchUsage(accessToken: accessToken)

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.fetchUsage(accessToken: accessToken)
        }
    }

    private func fetchUsage(accessToken: String) {
        Task { @MainActor in
            do {
                let response = try await UsageAPIClient.fetchUsage(accessToken: accessToken)
                self.errorMessage = nil

                if let fiveHour = response.five_hour {
                    self.usagePercent = fiveHour.utilization
                    self.isSessionActive = fiveHour.utilization > 0

                    if let resetStr = fiveHour.resets_at {
                        self.sessionResetDate = ISO8601DateFormatter().date(from: resetStr)
                            ?? Self.parseFlexibleISO8601(resetStr)
                    } else {
                        self.sessionResetDate = nil
                    }
                }

                if let sevenDay = response.seven_day {
                    self.weeklyUsagePercent = sevenDay.utilization
                }

                self.lastUpdated = Date()
            } catch let error as UsageAPIError {
                self.errorMessage = error.errorDescription
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Parses ISO 8601 strings with fractional seconds and timezone offsets
    /// that the strict ISO8601DateFormatter may reject.
    private static func parseFlexibleISO8601(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        return formatter.date(from: string)
    }

    // MARK: - Mock Data

    func startMockSession() {
        isUsingMockData = true
        isSessionActive = true
        tokensUsed = 135_000
        tokenLimit = 300_000
        usagePercent = Double(tokensUsed) / Double(tokenLimit) * 100.0
        sessionResetDate = Date().addingTimeInterval(3 * 60 * 60)  // 3 hours from now
    }

    func cycleMockUsage() {
        guard isUsingMockData else { return }

        let levels: [Double] = [0, 30, 45, 65, 85, 95, 100]
        let currentIndex = levels.firstIndex(where: { $0 >= usagePercent }) ?? 0
        let nextIndex = (currentIndex + 1) % levels.count
        let nextPercent = levels[nextIndex]

        if nextPercent == 0 {
            isSessionActive = false
            usagePercent = 0
            tokensUsed = 0
            sessionResetDate = nil
        } else {
            isSessionActive = true
            usagePercent = nextPercent
            tokensUsed = Int(Double(tokenLimit) * nextPercent / 100.0)
            if sessionResetDate == nil {
                sessionResetDate = Date().addingTimeInterval(3 * 60 * 60)
            }
        }
    }

    // MARK: - Session Management

    func resetSession() {
        usagePercent = 0
        weeklyUsagePercent = 0
        tokensUsed = 0
        sessionResetDate = nil
        isSessionActive = false
        pollTimer?.invalidate()
    }
}
