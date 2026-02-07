import SwiftUI

// MARK: - Popover Content View

struct PopoverView: View {
    @ObservedObject var usageManager: TokenUsageManager
    @State private var showingAPIKeyInput = false
    @State private var apiKeyText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Claude Token Cat")
                    .font(.headline)
                Spacer()
                Text(usageManager.catState.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(stateColor.opacity(0.2))
                    )
            }

            Divider()

            // Usage bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Token Usage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(usageManager.usagePercent)%")
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

                // Token count
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
            }

            Divider()

            // Session info
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(usageManager.timeRemainingFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Actions
            HStack(spacing: 8) {
                // Debug: cycle through states
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

                // Settings
                Button(action: {
                    showingAPIKeyInput.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // API Key input (expandable)
            if showingAPIKeyInput {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Anthropic API Key")
                        .font(.caption)
                        .fontWeight(.medium)
                    HStack {
                        SecureField("sk-ant-...", text: $apiKeyText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                        Button("Save") {
                            saveAPIKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    Text("Stored securely in Keychain")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
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
        case .running:  return .green
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

    private func saveAPIKey() {
        // TODO: Save to Keychain
        // For now, just dismiss
        showingAPIKeyInput = false
        apiKeyText = ""
    }
}
