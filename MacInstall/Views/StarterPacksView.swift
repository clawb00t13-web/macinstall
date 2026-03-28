import SwiftUI

struct StarterPacksView: View {
    @EnvironmentObject var store: AppStore
    @State private var customizingPack: StarterPack? = nil
    @State private var showingCreateSheet = false

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Starter Packs")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Pick a curated set and choose exactly which apps to install.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("New Pack", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                LazyVGrid(columns: columns, spacing: 16) {
                    // Custom packs first
                    ForEach(store.customPacks) { pack in
                        StarterPackCard(
                            pack: pack,
                            isApplied: store.appliedPackId == pack.id,
                            isCustom: true,
                            onDelete: {
                                store.deleteCustomPack(id: pack.id)
                            }
                        ) {
                            customizingPack = pack
                        }
                    }
                    // Built-in packs
                    ForEach(starterPacks) { pack in
                        StarterPackCard(
                            pack: pack,
                            isApplied: store.appliedPackId == pack.id
                        ) {
                            customizingPack = pack
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $customizingPack) { pack in
            PackCustomizeSheet(pack: pack) { selectedIds in
                store.applyStarterPack(appIds: selectedIds, packId: pack.id)
                customizingPack = nil
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreatePackSheet { name, icon, description, appIds in
                store.createCustomPack(name: name, icon: icon, description: description, appIds: appIds)
            }
            .environmentObject(store)
        }
    }
}

// MARK: - CreatePackSheet

struct CreatePackSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let onCreate: (String, String, String, [String]) -> Void

    @State private var name: String = ""
    @State private var icon: String = "📦"
    @State private var description: String = ""
    @State private var selectedAppIds: Set<String> = []
    @State private var appSearch: String = ""

    var filteredApps: [CatalogApp] {
        if appSearch.isEmpty { return store.apps }
        return store.apps.filter {
            $0.name.localizedCaseInsensitiveContains(appSearch) ||
            $0.description.localizedCaseInsensitiveContains(appSearch)
        }
    }

    var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedAppIds.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Pack")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Form fields
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    // Emoji field
                    TextField("📦", text: $icon)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: icon) { newValue in
                            // Keep only last character
                            let chars = Array(newValue)
                            if chars.count > 1 {
                                icon = String(chars.last!)
                            }
                        }

                    // Name field
                    TextField("Pack name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Description
                TextField("Description (optional)", text: $description)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // App selection header
            HStack {
                Text("Add Apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(selectedAppIds.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search apps…", text: $appSearch)
                    .font(.callout)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Divider()

            // App list
            List(filteredApps, id: \.id) { app in
                PackAppRow(app: app, isSelected: selectedAppIds.contains(app.id)) {
                    if selectedAppIds.contains(app.id) {
                        selectedAppIds.remove(app.id)
                    } else {
                        selectedAppIds.insert(app.id)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .listStyle(.plain)

            Divider()

            // Footer
            HStack {
                Text("\(selectedAppIds.count) app\(selectedAppIds.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button {
                    onCreate(
                        name.trimmingCharacters(in: .whitespaces),
                        icon.isEmpty ? "📦" : icon,
                        description.trimmingCharacters(in: .whitespaces),
                        Array(selectedAppIds)
                    )
                    dismiss()
                } label: {
                    Label("Create Pack", systemImage: "plus.circle.fill")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!canCreate)
            }
            .padding(20)
        }
        .frame(width: 560, height: 580)
    }
}

// MARK: - PackCustomizeSheet

struct PackCustomizeSheet: View {
    @EnvironmentObject var store: AppStore
    let pack: StarterPack
    let onApply: ([String]) -> Void

    @State private var selected: Set<String>
    @Environment(\.dismiss) private var dismiss

    init(pack: StarterPack, onApply: @escaping ([String]) -> Void) {
        self.pack = pack
        self.onApply = onApply
        _selected = State(initialValue: Set(pack.appIds))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                if pack.isCustom {
                    Text(pack.icon)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: pack.icon)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name)
                        .font(.headline)
                    Text(pack.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Select all / none
            HStack {
                Button("Select All") {
                    selected = Set(pack.appIds)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(Color.accentColor)

                Text("·")
                    .foregroundStyle(.secondary)

                Button("Deselect All") {
                    selected = []
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(Color.accentColor)

                Spacer()

                Text("\(selected.count) of \(pack.appIds.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            Divider()

            // App list
            List(pack.appIds, id: \.self) { id in
                if let app = store.apps.first(where: { $0.id == id }) {
                    PackAppRow(app: app, isSelected: selected.contains(id)) {
                        if selected.contains(id) {
                            selected.remove(id)
                        } else {
                            selected.insert(id)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button {
                    onApply(Array(selected))
                } label: {
                    Label("Apply \(selected.count) Apps", systemImage: "wand.and.stars")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(selected.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 480, height: 520)
    }
}

// MARK: - PackAppRow

struct PackAppRow: View {
    @EnvironmentObject var store: AppStore
    let app: CatalogApp
    let isSelected: Bool
    let onToggle: () -> Void

    var status: InstallStatus { store.installStatus[app.id] ?? .unknown }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .font(.system(size: 18))
                .onTapGesture { onToggle() }

            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 30, height: 30)
                .overlay {
                    Text(String(app.name.prefix(1)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                Text(app.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if status == .installed {
                Text("Installed")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .opacity(isSelected ? 1 : 0.5)
    }
}

// MARK: - StarterPackCard

struct StarterPackCard: View {
    @EnvironmentObject var store: AppStore
    let pack: StarterPack
    let isApplied: Bool
    var isCustom: Bool = false
    var onDelete: (() -> Void)? = nil
    let onCustomize: () -> Void

    @State private var confirmingDelete = false

    var appNames: String {
        let names = pack.appIds.compactMap { id in
            store.apps.first(where: { $0.id == id })?.name
        }
        let shown = names.prefix(4).joined(separator: ", ")
        let extra = names.count > 4 ? " +\(names.count - 4) more" : ""
        return shown + extra
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if isCustom {
                    Text(pack.icon)
                        .font(.title2)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: pack.icon)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                Text("\(pack.appCount) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())

                if isCustom {
                    Button {
                        confirmingDelete.toggle()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if confirmingDelete {
                HStack(spacing: 8) {
                    Text("Delete pack?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Delete", role: .destructive) {
                        onDelete?()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)

                    Button("Cancel") {
                        confirmingDelete = false
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pack.name)
                    .font(.headline)
                Text(pack.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(appNames)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Button(action: onCustomize) {
                HStack {
                    if isApplied {
                        Image(systemName: "checkmark")
                        Text("Applied — Customize")
                    } else {
                        Image(systemName: "wand.and.stars")
                        Text("Use This Pack")
                    }
                }
                .font(.callout)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isApplied ? .green : .accentColor)
            .controlSize(.regular)
        }
        .padding(16)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isApplied ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}
