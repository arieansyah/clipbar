import AppKit
import Combine

/// Menyimpan riwayat clipboard di ~/Library/Application Support/ClipBar.
final class ClipStore: ObservableObject {
    static let shared = ClipStore()

    @Published private(set) var items: [ClipItem] = []

    let baseDir: URL
    let imagesDir: URL
    private let dataURL: URL
    private var saveWork: DispatchWorkItem?
    private let imageCache = NSCache<NSString, NSImage>()

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseDir = support.appendingPathComponent("ClipBar", isDirectory: true)
        imagesDir = baseDir.appendingPathComponent("Images", isDirectory: true)
        dataURL = baseDir.appendingPathComponent("clips.json")
        imageCache.countLimit = 80
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
        cleanOrphanImages()
    }

    /// Item yang disematkan selalu di atas, sisanya berurutan dari yang terbaru.
    var displayItems: [ClipItem] { items.filter(\.pinned) + items.filter { !$0.pinned } }

    var pinnedCount: Int { items.filter(\.pinned).count }

    // MARK: - Mutasi

    func add(_ item: ClipItem) {
        if let idx = items.firstIndex(where: { $0.kind == item.kind && $0.contentHash == item.contentHash }) {
            var existing = items.remove(at: idx)
            existing.date = item.date
            existing.sourceBundleID = item.sourceBundleID ?? existing.sourceBundleID
            existing.sourceAppName = item.sourceAppName ?? existing.sourceAppName
            if let newFile = item.imageFile, newFile != existing.imageFile {
                try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(newFile))
            }
            items.insert(existing, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        trim()
        scheduleSave()
    }

    /// Dipanggil saat item dipakai lagi: naikkan ke posisi teratas.
    func touch(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: idx)
        item.date = Date()
        items.insert(item, at: 0)
        scheduleSave()
    }

    func togglePin(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned.toggle()
        scheduleSave()
    }

    func delete(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: idx)
        removeImage(of: removed)
        scheduleSave()
    }

    func clear(keepPinned: Bool) {
        let removed = items.filter { !keepPinned || !$0.pinned }
        items = keepPinned ? items.filter(\.pinned) : []
        removed.forEach(removeImage)
        scheduleSave()
    }

    func trim(max: Int? = nil) {
        let limit = max ?? AppSettings.shared.maxItems
        var kept: [ClipItem] = []
        var removed: [ClipItem] = []
        var unpinned = 0
        for item in items {
            if item.pinned {
                kept.append(item)
            } else if unpinned < limit {
                kept.append(item)
                unpinned += 1
            } else {
                removed.append(item)
            }
        }
        guard !removed.isEmpty else { return }
        items = kept
        removed.forEach(removeImage)
        scheduleSave()
    }

    // MARK: - Gambar

    func imageURL(for item: ClipItem) -> URL? {
        guard let file = item.imageFile else { return nil }
        return imagesDir.appendingPathComponent(file)
    }

    func image(for item: ClipItem) -> NSImage? {
        guard let url = imageURL(for: item) else { return nil }
        let key = url.path as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    private func removeImage(of item: ClipItem) {
        guard let url = imageURL(for: item) else { return }
        imageCache.removeObject(forKey: url.path as NSString)
        try? FileManager.default.removeItem(at: url)
    }

    private func cleanOrphanImages() {
        let referenced = Set(items.compactMap(\.imageFile))
        let files = (try? FileManager.default.contentsOfDirectory(atPath: imagesDir.path)) ?? []
        for file in files where !referenced.contains(file) {
            try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(file))
        }
    }

    // MARK: - Persistensi

    private func load() {
        guard let data = try? Data(contentsOf: dataURL) else { return }
        items = (try? JSONDecoder().decode([ClipItem].self, from: data)) ?? []
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: dataURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dataURL.path)
    }
}
