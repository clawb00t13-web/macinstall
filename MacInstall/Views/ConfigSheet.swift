import SwiftUI

struct ConfigSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let app: CatalogApp

    var configPaths: [ConfigPath] { appConfigPaths[app.id] ?? [] }
    var storedConfigs: [String: String] { store.appConfigs[app.id] ?? [:] }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(app.name) Config")
                        .font(.headline)
                    Text("Capture and sync your settings across Macs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Config paths list
            List(configPaths, id: \.key) { cp in
                ConfigPathRow(app: app, configPath: cp)
            }
            .listStyle(.plain)

            Divider()

            // Footer actions
            HStack {
                let capturedCount = configPaths.filter { storedConfigs[$0.key] != nil }.count
                Text("\(capturedCount) of \(configPaths.count) configs captured")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Capture All") {
                    store.captureAllConfigs(for: app)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button {
                    store.applyAllConfigs(for: app)
                    dismiss()
                } label: {
                    Label("Apply All", systemImage: "arrow.down.circle.fill")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(storedConfigs.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 520, height: 460)
    }
}

struct ConfigPathRow: View {
    @EnvironmentObject var store: AppStore
    let app: CatalogApp
    let configPath: ConfigPath

    @State private var showingDiff = false

    var storedContent: String? { store.appConfigs[app.id]?[configPath.key] }
    var currentContent: String? { readCurrentFile() }
    var hasDiff: Bool {
        guard let stored = storedContent, let current = currentContent else { return false }
        return stored != current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(configPath.description)
                            .font(.system(size: 13, weight: .medium))
                        if configPath.isSensitive {
                            Text("sensitive")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(configPath.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if hasDiff {
                    Button("Diff") { showingDiff.toggle() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                Button(storedContent == nil ? "Capture" : "Re-capture") {
                    store.captureConfig(for: app, key: configPath.key)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!configPath.exists)

                if storedContent != nil {
                    Button("Apply") {
                        store.applyConfig(for: app, key: configPath.key)
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if showingDiff, hasDiff {
                ConfigDiffView(stored: storedContent ?? "", current: currentContent ?? "")
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    private var statusColor: Color {
        guard storedContent != nil else { return .secondary.opacity(0.4) }
        return hasDiff ? .orange : .green
    }

    private func readCurrentFile() -> String? {
        guard configPath.exists else { return nil }
        return try? String(contentsOfFile: configPath.resolvedPath, encoding: .utf8)
    }
}

struct ConfigDiffView: View {
    let stored: String
    let current: String

    var body: some View {
        HStack(spacing: 1) {
            ScrollView {
                Text("Stored\n" + stored)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color.green.opacity(0.05))

            ScrollView {
                Text("Current\n" + current)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color.orange.opacity(0.05))
        }
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
    }
}
