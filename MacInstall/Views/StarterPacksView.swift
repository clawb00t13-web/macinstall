import SwiftUI

struct StarterPacksView: View {
    @EnvironmentObject var store: AppStore
    @State private var appliedPackId: String? = nil

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Starter Packs")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Apply a curated set of apps to your profile in one click.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(starterPacks) { pack in
                        StarterPackCard(
                            pack: pack,
                            isApplied: appliedPackId == pack.id
                        ) {
                            store.applyStarterPack(pack)
                            appliedPackId = pack.id
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

struct StarterPackCard: View {
    @EnvironmentObject var store: AppStore
    let pack: StarterPack
    let isApplied: Bool
    let onApply: () -> Void

    var appNames: String {
        let names = pack.appIds.compactMap { id in
            store.apps.first(where: { $0.id == id })?.name
        }
        let shown = names.prefix(5).joined(separator: ", ")
        let extra = names.count > 5 ? " +\(names.count - 5) more" : ""
        return shown + extra
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: pack.icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Text("\(pack.appCount) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
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

            Button(action: onApply) {
                HStack {
                    if isApplied {
                        Image(systemName: "checkmark")
                        Text("Applied!")
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
