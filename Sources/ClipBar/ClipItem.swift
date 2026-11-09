import AppKit
import SwiftUI

enum ClipKind: String, Codable, CaseIterable {
    case text, link, color, image, file

    var label: String {
        switch self {
        case .text: return "Teks"
        case .link: return "Tautan"
        case .color: return "Warna"
        case .image: return "Gambar"
        case .file: return "File"
        }
    }

    var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .color: return "paintpalette.fill"
        case .image: return "photo.fill"
        case .file: return "doc.fill"
        }
    }

    var tint: Color {
        switch self {
        case .text: return Color(red: 0.40, green: 0.43, blue: 0.97)
        case .link: return Color(red: 0.10, green: 0.60, blue: 0.95)
        case .color: return Color(red: 0.97, green: 0.47, blue: 0.20)
        case .image: return Color(red: 0.16, green: 0.72, blue: 0.47)
        case .file: return Color(red: 0.64, green: 0.40, blue: 0.95)
        }
    }
}

struct ClipItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: ClipKind
    var text: String
    var imageFile: String?
    var imageWidth: Double?
    var imageHeight: Double?
    var contentHash: String
    var sourceBundleID: String?
    var sourceAppName: String?
    var date: Date
    var pinned: Bool = false

    var title: String {
        switch kind {
        case .image:
            if let w = imageWidth, let h = imageHeight { return "Gambar \(Int(w))×\(Int(h))" }
            return "Gambar"
        case .file:
            let names = fileURLs.map(\.lastPathComponent)
            if names.count > 1 { return "\(names[0]) +\(names.count - 1) lainnya" }
            return names.first ?? "File"
        default:
            let firstLine = text
                .split(whereSeparator: \.isNewline)
                .lazy
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? text
            return String(firstLine.prefix(300))
        }
    }

    var fileURLs: [URL] {
        guard kind == .file else { return [] }
        return text.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
    }

    var nsColor: NSColor? { kind == .color ? NSColor(hex: text) : nil }

    var previewText: String {
        let limit = 20_000
        return text.count > limit ? String(text.prefix(limit)) + "\n…" : text
    }

    func matches(_ query: String) -> Bool {
        let opts: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        if text.range(of: query, options: opts) != nil { return true }
        if title.range(of: query, options: opts) != nil { return true }
        if let app = sourceAppName, app.range(of: query, options: opts) != nil { return true }
        return kind.label.range(of: query, options: opts) != nil
    }

    var stats: String {
        switch kind {
        case .image:
            if let w = imageWidth, let h = imageHeight { return "\(Int(w)) × \(Int(h)) px" }
            return "Gambar"
        case .file:
            return "\(fileURLs.count) file"
        default:
            let chars = text.count
            let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
            return "\(chars) karakter · \(words) kata · \(lines) baris"
        }
    }
}

enum ClipFilter: String, CaseIterable, Identifiable {
    case all, pinned, text, link, image, file, color

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Semua"
        case .pinned: return "Disematkan"
        case .text: return "Teks"
        case .link: return "Tautan"
        case .image: return "Gambar"
        case .file: return "File"
        case .color: return "Warna"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "square.stack.3d.up.fill"
        case .pinned: return "pin.fill"
        case .text: return ClipKind.text.symbol
        case .link: return ClipKind.link.symbol
        case .image: return ClipKind.image.symbol
        case .file: return ClipKind.file.symbol
        case .color: return ClipKind.color.symbol
        }
    }

    func matches(_ item: ClipItem) -> Bool {
        switch self {
        case .all: return true
        case .pinned: return item.pinned
        case .text: return item.kind == .text
        case .link: return item.kind == .link
        case .image: return item.kind == .image
        case .file: return item.kind == .file
        case .color: return item.kind == .color
        }
    }
}
