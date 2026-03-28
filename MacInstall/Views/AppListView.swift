import SwiftUI

struct AppListView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps...", text: $store.searchQuery)
                    .textFieldStyle(.plain)
                if !store.searchQuery.isEmpty {
                    Button {
                        store.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Category filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appCategories, id: \.self) { category in
                        CategoryPill(category: category, isSelected: store.selectedCategory == category) {
                            store.selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            Divider()
                .padding(.top, 4)

            // App list
            List(store.filteredApps) { app in
                AppRowView(app: app)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            .listStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: store.filteredApps.map(\.id))

            Divider()

            // Bottom toolbar
            HStack(spacing: 12) {
                Text("\(store.filteredApps.count) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if store.isDetecting {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Detecting...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        Task { await store.detectInstalled() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    store.installMissing()
                } label: {
                    Label("Install Missing", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(store.missingEnabledApps.isEmpty || store.isInstalling)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

struct CategoryPill: View {
    let category: String
    let isSelected: Bool
    let action: () -> Void

    var displayName: String {
        switch category {
        case "all": return "All"
        case "developer": return "Developer"
        case "designer": return "Designer"
        case "productivity": return "Productivity"
        case "content-creator": return "Content Creator"
        case "data-science": return "Data Science"
        case "communication": return "Communication"
        case "utilities": return "Utilities"
        case "browser": return "Browser"
        case "security": return "Security"
        case "ai": return "AI"
        default: return category.capitalized
        }
    }

    var body: some View {
        Button(action: action) {
            Text(displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct AppRowView: View {
    @EnvironmentObject var store: AppStore
    let app: CatalogApp
    @State private var showingUninstallAlert = false
    @State private var showingConfigSheet = false
    var hasConfigPaths: Bool { appConfigPaths[app.id] != nil }
    var hasCapturedConfig: Bool { store.appConfigs[app.id] != nil }

    var status: InstallStatus { store.installStatus[app.id] ?? .unknown }

    var statusText: String {
        switch status {
        case .installed: return "Installed"
        case .notInstalled: return "Not installed"
        case .installing: return "Installing..."
        case .unknown: return "Unknown"
        }
    }

    var statusColor: Color {
        switch status {
        case .installed: return .green
        case .notInstalled: return .secondary
        case .installing: return .orange
        case .unknown: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(app.name.prefix(1)))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                Text(app.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .frame(width: 80, alignment: .leading)

                if hasConfigPaths {
                    Button {
                        showingConfigSheet = true
                    } label: {
                        Image(systemName: hasCapturedConfig ? "gearshape.fill" : "gearshape")
                            .font(.caption)
                            .foregroundStyle(hasCapturedConfig ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(hasCapturedConfig ? "Config captured — click to manage" : "Capture app config")
                }

                if status == .installed {
                    Button {
                        showingUninstallAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Uninstall \(app.name)")
                }
            }
        }
        .contentShape(Rectangle())
        .alert("Uninstall \(app.name)?", isPresented: $showingUninstallAlert) {
            Button("Uninstall", role: .destructive) {
                Task { await store.uninstallApp(app) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(app.name) from your Mac.")
        }
        .sheet(isPresented: $showingConfigSheet) {
            ConfigSheet(app: app)
                .environmentObject(store)
        }
    }
}
