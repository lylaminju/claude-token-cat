import SwiftUI

// MARK: - Popover Content View

struct PopoverView: View {
    @ObservedObject var usageManager: TokenUsageManager

    var body: some View {
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
                if usageManager.isUsingMockData {
                    HStack {
                        Text(formatTokenCount(usageManager.tokensUsed))
                            .font(.system(.caption, design: .monospaced))
                        Text("/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTokenCount(usageManager.tokenLimit))
                            .font(.system(.caption, design: .monospaced))
                        Text("tokens")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
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
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                    Text("Run `claude login` to connect")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Quit
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
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Helpers

    private var stateColor: Color {
        switch usageManager.catState {
        case .idle:     return .blue
        case .jumping:  return .green
        case .walking:  return .yellow
        case .tired:    return .orange
        case .sleeping: return .red
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}
