import SwiftUI

// MARK: - Popover Content View

struct PopoverView: View {
    @ObservedObject var usageManager: TokenUsageManager
    @State private var showSettings: Bool = false

    var body: some View {
        Group {
            if showSettings {
                settingsView
            } else {
                mainView
            }
        }
        .frame(width: 280)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .popoverDidClose)) { _ in
            showSettings = false
        }
    }

    // MARK: - Main View

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Claude Token Cat")
                        .font(.headline)
                    Spacer()
                    Link(destination: URL(string: "https://claude.ai/settings/usage")!) {
                        HStack(spacing: 2) {
                            Text("Account")
                                .font(.caption)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    if let sub = usageManager.subscriptionType {
                        Text(sub)
                            .font(.system(size: 9))
                            .fontWeight(.medium)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.15))
                            )
                            .foregroundColor(.accentColor)
                    }
                    if let email = usageManager.accountEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Divider()

            // Session usage
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Session Usage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(usageManager.usagePercent))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(stateColor)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(stateColor)
                            .frame(width: geo.size.width * usageManager.usageRatio, height: 8)
                    }
                }
                .frame(height: 8)

                // Detail line
                if !usageManager.isUsingMockData {
                    Text(usageManager.timeRemaining != nil ? "Resets in \(usageManager.timeRemainingFormatted)" : "No active session")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Weekly usage (real data only)
            if !usageManager.isUsingMockData && usageManager.weeklyUsagePercent > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Weekly Usage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(usageManager.weeklyUsagePercent))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: geo.size.width * min(usageManager.weeklyUsagePercent / 100.0, 1.0), height: 4)
                        }
                    }
                    .frame(height: 4)

                    if let formatted = usageManager.weeklyResetFormatted {
                        Text("Resets \(formatted)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Extra usage (real data only)
            if !usageManager.isUsingMockData && usageManager.extraUsageEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Extra Usage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", usageManager.extraUsageUsed / 100.0)) / $\(usageManager.extraUsageLimit / 100)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.blue.opacity(0.6))
                                .frame(width: geo.size.width * min(usageManager.extraUsagePercent / 100.0, 1.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }

            // Error message
            if let error = usageManager.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Divider()

            // Connection status / actions
            if usageManager.isUsingMockData {
                HStack(spacing: 8) {
                    Button(action: {
                        usageManager.cycleMockUsage()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Cycle State")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let updated = usageManager.lastUpdated {
                        Text("Updated at")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(updated, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Button(action: {
                        usageManager.refresh()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .offset(y: -0.5)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }

            if usageManager.isUsingMockData {
                if usageManager.keychainAccessDenied {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text("Keychain access denied.\nAllow in Keychain Access.app")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                        Text("Run `claude login` to connect")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Settings + Quit
            HStack {
                Button(action: { showSettings = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
    }

    // MARK: - Settings View

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with back button
            HStack(spacing: 6) {
                Button(action: { showSettings = false }) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Text("Settings")
                    .font(.headline)

                Spacer()
            }

            Divider()

            // Animation toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Animation")
                        .font(.subheadline)
                    Text("Animate the cat in the menu bar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $usageManager.animationEnabled)
                    .toggleStyle(MiniSwitchStyle())
                    .labelsHidden()
            }
        }
        .padding(16)
    }

    // MARK: - Helpers

    private var stateColor: Color {
        switch usageManager.catState {
        case .idle:     return .blue
        case .jumping:  return .green
        case .walking:  return .yellow
        case .tired:    return .orange
        case .sleeping: return Color(red: 0.85, green: 0.35, blue: 0.45)
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - Mini Switch Toggle Style

/// Custom switch style that reliably shows blue/gray in NSPopover contexts,
/// where the native NSSwitch ignores `.tint()`.
private struct MiniSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Use Button instead of .onTapGesture — NSMenu's event tracking swallows gesture recognizers
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 4) {
                configuration.label
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 26, height: 15)
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 0.5, y: 0.5)
                        .frame(width: 13, height: 13)
                        .padding(.horizontal, 1)
                }
                .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let popoverDidClose = Notification.Name("popoverDidClose")
}
