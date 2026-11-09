import AppKit
import SwiftUI

struct PreviewPane: View {
    let item: ClipItem?
    @ObservedObject var store: ClipStore
    @ObservedObject var settings: AppSettings
    let actions: PanelActions

    var body: some View {
        if let item {
            content(item)
        } else {
            EmptyStateView(symbol: "eye", title: "Tidak ada pratinjau", subtitle: "Pilih item di sebelah kiri.")
        }
    }

    private func content(_ item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                KindBadge(kind: item.kind)
                if item.pinned {
                    Label("Disematkan", systemImage: "pin.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                Spacer()
                IconButton(symbol: item.pinned ? "pin.slash" : "pin",
                           help: item.pinned ? "Lepas sematan (⌘P)" : "Sematkan (⌘P)") { actions.togglePin(item) }
                IconButton(symbol: "doc.on.doc", help: "Salin ke clipboard (⌘↩)") { actions.copyOnly(item) }
                IconButton(symbol: "trash", help: "Hapus (⌘⌫)", tint: .red) { actions.delete(item) }
            }

            contentBody(item)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            MetaView(item: item)

            Button { actions.paste(item) } label: {
                HStack {
                    Image(systemName: settings.autoPaste ? "arrow.down.doc.fill" : "doc.on.clipboard.fill")
                    Text(settings.autoPaste ? "Tempel ke aplikasi" : "Salin ke clipboard")
                    Spacer()
                    Text("↩").opacity(0.75)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.gradient))
                .shadow(color: Brand.violet.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    @ViewBuilder
    private func contentBody(_ item: ClipItem) -> some View {
        switch item.kind {
        case .text:
            ScrollView {
                Text(item.previewText)
                    .font(.system(size: 12.5, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
        case .link:
            LinkPreview(urlString: item.text)
        case .color:
            ColorPreview(item: item)
        case .image:
            if let image = store.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
            } else {
                EmptyStateView(symbol: "photo", title: "Gambar tidak tersedia", subtitle: "File gambar sudah dihapus.")
            }
        case .file:
            FilePreview(urls: item.fileURLs)
        }
    }
}

private struct MetaView: View {
    let item: ClipItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Sumber") {
                HStack(spacing: 6) {
                    if let icon = AppIcons.icon(for: item.sourceBundleID) {
                        Image(nsImage: icon).resizable().frame(width: 15, height: 15)
                    }
                    Text(item.sourceAppName ?? "—")
                }
            }
            row("Disalin") { Text(Fmt.full.string(from: item.date)) }
            row("Ukuran") { Text(item.stats) }
        }
        .font(.system(size: 11.5))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    private func row<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        HStack(spacing: 8) {
            Text(label).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
            value().lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

private struct LinkPreview: View {
    let urlString: String

    var body: some View {
        let url = URL(string: urlString)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ClipKind.link.tint.gradient)
                    Image(systemName: url?.scheme == "mailto" ? "envelope.fill" : "globe")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(url?.host ?? urlString)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text(url?.scheme?.uppercased() ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Text(urlString)
                .font(.system(size: 12.5, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(8)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
            if let url {
                Button { NSWorkspace.shared.open(url) } label: {
                    Label("Buka di browser", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.link)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ColorPreview: View {
    let item: ClipItem

    var body: some View {
        let color = item.nsColor?.usingColorSpace(.sRGB) ?? NSColor.gray
        let r = Int(round(color.redComponent * 255))
        let g = Int(round(color.greenComponent * 255))
        let b = Int(round(color.blueComponent * 255))
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: color))
                .frame(height: 150)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
                .overlay(alignment: .bottomLeading) {
                    Text(item.text.uppercased())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(color.isLight ? Color.black.opacity(0.75) : Color.white)
                        .padding(14)
                }
            valueRow("HEX", item.text.uppercased())
            valueRow("RGB", "\(r), \(g), \(b)")
            valueRow("HSB", "\(Int(color.hueComponent * 360))°, \(Int(color.saturationComponent * 100))%, \(Int(color.brightnessComponent * 100))%")
            Spacer(minLength: 0)
        }
    }

    private func valueRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
            Text(value).font(.system(size: 13, design: .monospaced)).textSelection(.enabled)
        }
    }
}

private struct FilePreview: View {
    let urls: [URL]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(urls, id: \.self) { url in
                    let exists = FileManager.default.fileExists(atPath: url.path)
                    HStack(spacing: 10) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Text(exists ? Fmt.shortPath(url.deletingLastPathComponent().path) : "File tidak ditemukan")
                                .font(.system(size: 11))
                                .foregroundStyle(exists ? Color.secondary : Color.red)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        if exists {
                            Button("Tampilkan") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                .controlSize(.small)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
                }
            }
        }
    }
}
