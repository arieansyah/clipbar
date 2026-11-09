import AppKit
import SwiftUI

struct PanelActions {
    var paste: (ClipItem) -> Void
    var copyOnly: (ClipItem) -> Void
    var togglePin: (ClipItem) -> Void
    var delete: (ClipItem) -> Void
    var openSettings: () -> Void
}

final class PanelModel: ObservableObject {
    @Published var query = ""
    @Published var filter: ClipFilter = .all
    @Published var selectedID: UUID?
    @Published var focusToken = 0

    func results(from store: ClipStore) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return store.displayItems.filter { filter.matches($0) && (q.isEmpty || $0.matches(q)) }
    }

    func selection(in results: [ClipItem]) -> ClipItem? {
        results.first { $0.id == selectedID } ?? results.first
    }
}

struct PanelView: View {
    @ObservedObject var store: ClipStore
    @ObservedObject var model: PanelModel
    @ObservedObject var settings: AppSettings
    let actions: PanelActions
    @FocusState private var searchFocused: Bool

    var body: some View {
        let results = model.results(from: store)
        let selected = model.selection(in: results)

        VStack(spacing: 0) {
            header
            filterBar
            Divider().opacity(0.5)
            HStack(spacing: 0) {
                list(results, selected: selected)
                    .frame(width: 370)
                Divider().opacity(0.5)
                PreviewPane(item: selected, store: store, settings: settings, actions: actions)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider().opacity(0.5)
            footer(count: results.count)
        }
        .frame(width: PanelController.size.width, height: PanelController.size.height)
        .background(
            ZStack {
                VisualEffectBackground(material: .popover, cornerRadius: 18)
                LinearGradient(colors: [Brand.violet.opacity(0.10), .clear, Brand.pink.opacity(0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { _ in searchFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Brand.gradient)
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
            .shadow(color: Brand.violet.opacity(0.4), radius: 6, y: 2)

            TextField("Cari di riwayat clipboard…", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($searchFocused)
                .onChange(of: model.query) { _ in model.selectedID = nil }

            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if settings.paused {
                Label("Dijeda", systemImage: "pause.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.18)))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Filter

    private var filterBar: some View {
        let all = store.displayItems
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ClipFilter.allCases) { filter in
                    let count = all.filter(filter.matches).count
                    FilterChip(filter: filter, count: count, selected: model.filter == filter) {
                        model.filter = filter
                        model.selectedID = nil
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 10)
    }

    // MARK: - Daftar

    @ViewBuilder
    private func list(_ results: [ClipItem], selected: ClipItem?) -> some View {
        if results.isEmpty {
            if store.items.isEmpty {
                EmptyStateView(symbol: "doc.on.clipboard",
                               title: "Belum ada yang disalin",
                               subtitle: "Salin teks, tautan, gambar, atau file. Semuanya akan muncul di sini.")
            } else {
                EmptyStateView(symbol: "magnifyingglass",
                               title: "Tidak ditemukan",
                               subtitle: "Coba kata kunci atau filter lain.")
            }
        } else {
            let hasPinned = results.contains(where: \.pinned)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            VStack(alignment: .leading, spacing: 2) {
                                if hasPinned && index == 0 && item.pinned {
                                    SectionLabel(text: "Disematkan")
                                } else if hasPinned && !item.pinned && (index == 0 || results[index - 1].pinned) {
                                    SectionLabel(text: "Riwayat").padding(.top, 6)
                                }
                                ClipRow(item: item, index: index, isSelected: item.id == selected?.id, store: store)
                                    .contentShape(Rectangle())
                                    .onTapGesture { model.selectedID = item.id }
                                    .simultaneousGesture(TapGesture(count: 2).onEnded { actions.paste(item) })
                                    .contextMenu { contextMenu(for: item) }
                            }
                            .id(item.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: model.selectedID) { id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for item: ClipItem) -> some View {
        Button(settings.autoPaste ? "Tempel" : "Salin") { actions.paste(item) }
        Button("Salin ke clipboard") { actions.copyOnly(item) }
        Divider()
        Button(item.pinned ? "Lepas sematan" : "Sematkan") { actions.togglePin(item) }
        if item.kind == .file, let url = item.fileURLs.first {
            Button("Tampilkan di Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        if item.kind == .link, let url = URL(string: item.text) {
            Button("Buka di browser") { NSWorkspace.shared.open(url) }
        }
        Divider()
        Button("Hapus", role: .destructive) { actions.delete(item) }
    }

    // MARK: - Footer

    private func footer(count: Int) -> some View {
        HStack(spacing: 14) {
            KeyHint(key: "↩", label: settings.autoPaste ? "Tempel" : "Salin")
            if settings.autoPaste { KeyHint(key: "⌘↩", label: "Salin saja") }
            KeyHint(key: "⌘1–9", label: "Cepat")
            KeyHint(key: "⌘P", label: "Sematkan")
            KeyHint(key: "⌘⌫", label: "Hapus")
            KeyHint(key: "⇥", label: "Filter")
            Spacer()
            Text("\(count) item")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button(action: actions.openSettings) {
                Image(systemName: "gearshape.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Pengaturan (⌘,)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

// MARK: - Baris

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let filter: ClipFilter
    let count: Int
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: filter.symbol).font(.system(size: 9.5, weight: .bold))
                Text(filter.label)
                if count > 0 {
                    Text("\(count)").opacity(0.65)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(selected ? Color.white : Color.primary.opacity(count == 0 ? 0.4 : 0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(selected
                               ? AnyShapeStyle(Brand.gradient)
                               : AnyShapeStyle(Color.primary.opacity(hovering ? 0.1 : 0.06)))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let store: ClipStore
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 11) {
            ClipThumb(item: item, store: store, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(item.sourceAppName ?? item.kind.label)
                    Text("·")
                    Text(Fmt.ago(item.date))
                }
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            if item.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(35))
                    .foregroundStyle(isSelected ? Color.white : Color.orange)
            }
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(isSelected ? Color.white.opacity(0.22) : Color.primary.opacity(0.07)))
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
            }
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected
                      ? AnyShapeStyle(Brand.gradient)
                      : AnyShapeStyle(Color.primary.opacity(hovering ? 0.06 : 0)))
        )
        .shadow(color: isSelected ? Brand.violet.opacity(0.35) : .clear, radius: 8, y: 3)
        .onHover { hovering = $0 }
    }
}
