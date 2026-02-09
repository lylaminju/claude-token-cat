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
    @Published private(set) var extraUsageEnabled: Bool = false
    @Published private(set) var extraUsagePercent: Double = 0
    @Published private(set) var extraUsageUsed: Double = 0
    @Published private(set) var extraUsageLimit: Int = 0
    @Published private(set) var sessionResetDate: Date? = nil
    @Published private(set) var isSessionActive: Bool = false
    @Published private(set) var isUsingMockData: Bool = true
    @Published private(set) var keychainAccessDenied: Bool = false
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var accountEmail: String? = nil
    @Published private(set) var subscriptionType: String? = nil

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
        case 0..<40:    return .jumping
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

    /// Formatted time remaining string (e.g. "2h 50m")
    var timeRemainingFormatted: String {
        guard let remaining = timeRemaining else { return "no active session" }
        if remaining <= 0 { return "now" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    // MARK: - Configuration

    private let pollInterval: TimeInterval = 5 * 60  // 5 minutes
    private var accessToken: String?

    private static let iso8601Formatter = ISO8601DateFormatter()
    private static let flexibleISO8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        return formatter
    }()

    // MARK: - Timers

    private var pollTimer: Timer?
    private var fetchTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        switch ClaudeCodeCredentials.loadAccessToken() {
        case .success(let token):
            isUsingMockData = false
            accessToken = token
            fetchProfile(accessToken: token)
            startPolling(accessToken: token)
        case .accessDenied:
            isUsingMockData = true
            keychainAccessDenied = true
            startMockSession()
        case .notFound:
            isUsingMockData = true
            startMockSession()
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Profile

    private func fetchProfile(accessToken: String) {
        Task { @MainActor in
            if let profile = try? await UsageAPIClient.fetchProfile(accessToken: accessToken) {
                self.accountEmail = profile.account.email
                self.subscriptionType = Self.formatSubscriptionType(profile.organization?.organization_type)
            }
        }
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
        fetchTask?.cancel()
        fetchTask = Task { @MainActor in
            do {
                let response = try await UsageAPIClient.fetchUsage(accessToken: accessToken)
                self.errorMessage = nil

                if let fiveHour = response.five_hour {
                    self.usagePercent = fiveHour.utilization
                    self.isSessionActive = fiveHour.utilization > 0

                    if let resetStr = fiveHour.resets_at {
                        self.sessionResetDate = Self.iso8601Formatter.date(from: resetStr)
                            ?? Self.flexibleISO8601Formatter.date(from: resetStr)
                    } else {
                        self.sessionResetDate = nil
                    }
                }

                if let sevenDay = response.seven_day {
                    self.weeklyUsagePercent = sevenDay.utilization
                }

                if let extra = response.extra_usage {
                    self.extraUsageEnabled = extra.is_enabled
                    self.extraUsagePercent = extra.utilization ?? 0
                    self.extraUsageUsed = extra.used_credits ?? 0
                    self.extraUsageLimit = extra.monthly_limit ?? 0
                }

                self.lastUpdated = Date()
            } catch UsageAPIError.unauthorized {
                // Token may have been refreshed by Claude Code - retry with fresh credentials
                if case .success(let freshToken) = ClaudeCodeCredentials.loadAccessToken(), freshToken != accessToken {
                    self.accessToken = freshToken
                    self.fetchProfile(accessToken: freshToken)
                    self.startPolling(accessToken: freshToken)
                } else {
                    self.errorMessage = UsageAPIError.unauthorized.errorDescription
                }
            } catch let error as UsageAPIError {
                self.errorMessage = error.errorDescription
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Mock Data

    func startMockSession() {
        isUsingMockData = true
        isSessionActive = false
        tokensUsed = 0
        tokenLimit = 300_000
        usagePercent = 0
        sessionResetDate = nil
    }

    func cycleMockUsage() {
        guard isUsingMockData else { return }

        let levels: [Double] = [00, 20, 60, 90, 100]
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

    // MARK: - Manual Refresh

    func refresh() {
        guard let token = accessToken else { return }
        fetchUsage(accessToken: token)
    }

    private static func formatSubscriptionType(_ type: String?) -> String? {
        switch type {
        case "claude_free": return "Free"
        case "claude_pro": return "Pro"
        case "claude_max": return "Max"
        case "claude_team": return "Team"
        case "claude_enterprise": return "Enterprise"
        default: return nil
        }
    }

    // MARK: - Session Management

    func resetSession() {
        usagePercent = 0
        weeklyUsagePercent = 0
        extraUsageEnabled = false
        extraUsagePercent = 0
        extraUsageUsed = 0
        extraUsageLimit = 0
        tokensUsed = 0
        sessionResetDate = nil
        isSessionActive = false
        pollTimer?.invalidate()
    }
}
