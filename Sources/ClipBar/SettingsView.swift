import AppKit
import ServiceManagement
import SwiftUI

enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                             styleMask: [.titled, .closable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Pengaturan ClipBar"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = ClipStore.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var axTrusted = Paster.isTrusted
    @State private var confirmClear = false
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
            Form {
                Section("Umum") {
                    Toggle("Buka ClipBar saat login", isOn: $launchAtLogin)
                    Picker("Pintasan keyboard", selection: $settings.hotKey) {
                        ForEach(HotKeyPreset.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section("Tempel") {
                    Toggle("Tempel otomatis ke aplikasi aktif", isOn: $settings.autoPaste)
                    if settings.autoPaste && !axTrusted {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("Butuh izin Aksesibilitas agar bisa menekan ⌘V untuk Anda.")
                                .font(.system(size: 12))
                            Spacer()
                            Button("Beri Izin") { Paster.requestAccess() }
                        }
                    }
                }

                Section("Riwayat") {
                    Picker("Simpan maksimal", selection: $settings.maxItems) {
                        ForEach([50, 100, 200, 500, 1000], id: \.self) { Text("\($0) item").tag($0) }
                    }
                    Toggle("Jeda pemantauan clipboard", isOn: $settings.paused)
                    HStack {
                        Text("\(store.items.count) item tersimpan · \(store.pinnedCount) disematkan")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Hapus Riwayat…", role: .destructive) { confirmClear = true }
                    }
                }

                Section("Privasi") {
                    Label("Isi dari pengelola kata sandi (1Password, Bitwarden, Passwords, Keychain) dan data yang ditandai rahasia tidak pernah disimpan.",
                          systemImage: "lock.shield.fill")
                        .font(.system(size: 12))
                    Label("Riwayat hanya disimpan di Mac ini, tidak pernah dikirim ke mana pun.",
                          systemImage: "internaldrive.fill")
                        .font(.system(size: 12))
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 640)
        .onChange(of: launchAtLogin) { enabled in
            do {
                if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("ClipBar: gagal mengubah login item: \(error)")
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .onReceive(timer) { _ in axTrusted = Paster.isTrusted }
        .alert("Hapus riwayat clipboard?", isPresented: $confirmClear) {
            Button("Hapus", role: .destructive) { store.clear(keepPinned: true) }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Item yang disematkan tetap disimpan.")
        }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text("ClipBar").font(.system(size: 22, weight: .bold))
                Text("Versi \(version) · Pengelola clipboard untuk macOS")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 34)
        .padding(.bottom, 4)
    }
}
