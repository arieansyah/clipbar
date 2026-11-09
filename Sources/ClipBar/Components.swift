import AppKit
import SwiftUI

// MARK: - Brand

enum Brand {
    static let indigo = Color(red: 0.36, green: 0.36, blue: 0.96)
    static let violet = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let pink = Color(red: 0.93, green: 0.30, blue: 0.62)

    static let gradient = LinearGradient(colors: [indigo, violet, pink],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Formatter & cache

enum Fmt {
    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.unitsStyle = .short
        return f
    }()

    static let full: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func ago(_ date: Date) -> String {
        if -date.timeIntervalSinceNow < 45 { return "baru saja" }
        return relative.localizedString(for: date, relativeTo: Date())
    }

    static func shortPath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

enum AppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let cached = cache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleID] = icon
        return icon
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: CGFloat
        if s.count == 6 {
            r = CGFloat((v >> 16) & 0xFF) / 255
            g = CGFloat((v >> 8) & 0xFF) / 255
            b = CGFloat(v & 0xFF) / 255
            a = 1
        } else {
            r = CGFloat((v >> 24) & 0xFF) / 255
            g = CGFloat((v >> 16) & 0xFF) / 255
            b = CGFloat((v >> 8) & 0xFF) / 255
            a = CGFloat(v & 0xFF) / 255
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }

    var isLight: Bool {
        guard let c = usingColorSpace(.sRGB) else { return true }
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent > 0.62
    }
}

// MARK: - Background

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        if cornerRadius > 0 { view.maskImage = Self.mask(radius: cornerRadius) }
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }

    private static func mask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

// MARK: - Komponen kecil

struct KindBadge: View {
    let kind: ClipKind

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: kind.symbol).font(.system(size: 9.5, weight: .bold))
            Text(kind.label.uppercased()).font(.system(size: 10.5, weight: .bold)).tracking(0.6)
        }
        .foregroundStyle(kind.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(kind.tint.opacity(0.15)))
    }
}

struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.08)))
            Text(label).font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    var tint: Color = .primary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.12 : 0.06)))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Brand.gradient).opacity(0.14)
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Brand.gradient)
            }
            .frame(width: 70, height: 70)
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClipThumb: View {
    let item: ClipItem
    let store: ClipStore
    var size: CGFloat = 36

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            main.frame(width: size, height: size)
            if item.kind == .text || item.kind == .link, let icon = AppIcons.icon(for: item.sourceBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: size * 0.5, height: size * 0.5)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                    .offset(x: 5, y: 5)
            }
        }
    }

    @ViewBuilder private var main: some View {
        switch item.kind {
        case .image:
            if let image = store.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12)))
            } else {
                symbolTile
            }
        case .color:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: item.nsColor ?? .gray))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15)))
        case .file:
            if let first = item.fileURLs.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first.path)).resizable()
            } else {
                symbolTile
            }
        default:
            symbolTile
        }
    }

    private var symbolTile: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(item.kind.tint.gradient)
            .overlay(
                Image(systemName: item.kind.symbol)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}
