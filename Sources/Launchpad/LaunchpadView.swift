import AppKit
import SwiftUI

struct InstalledApp: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleID: String
    var id: String { bundleID.isEmpty ? url.path : bundleID }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

struct AppFolder: Codable, Identifiable {
    var id = UUID().uuidString
    var name = "文件夹"
    var appIDs: [String]
}

struct SavedLayout: Codable {
    var order: [String] = []
    var folders: [AppFolder] = []
}

@MainActor
final class AppCatalog: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    @Published var isLoading = false
    @Published var layout = SavedLayout() { didSet { saveLayout() } }
    private let layoutKey = "launchpad.layout.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: layoutKey), let value = try? JSONDecoder().decode(SavedLayout.self, from: data) { layout = value }
    }
    private func saveLayout() { if let data = try? JSONEncoder().encode(layout) { UserDefaults.standard.set(data, forKey: layoutKey) } }

    func refresh() {
        guard !isLoading else { return }; isLoading = true
        Task.detached(priority: .userInitiated) {
            let roots = [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"), URL(fileURLWithPath: "/System/Applications/Utilities"), FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications")]
            var found: [String: InstalledApp] = [:]
            for root in roots {
                guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isApplicationKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
                for case let url as URL in e where url.pathExtension == "app" {
                    guard (try? url.resourceValues(forKeys: [.isApplicationKey]).isApplication) == true else { continue }
                    let bundle = Bundle(url: url), id = bundle?.bundleIdentifier ?? url.path
                    let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? url.deletingPathExtension().lastPathComponent
                    found[id] = InstalledApp(url: url, name: name, bundleID: id); e.skipDescendants()
                }
            }
            let result = found.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            await MainActor.run { self.apps = result; self.isLoading = false; self.normalizeOrder() }
        }
    }
    func normalizeOrder() {
        let valid = Set(apps.map(\.id)); layout.order = layout.order.filter { valid.contains($0) }
        layout.order += apps.map(\.id).filter { !layout.order.contains($0) }
        layout.folders = layout.folders.compactMap { folder in var f = folder; f.appIDs = f.appIDs.filter { valid.contains($0) }; return f.appIDs.count > 1 ? f : nil }
    }
    func app(_ id: String) -> InstalledApp? { apps.first { $0.id == id } }
    func open(_ app: InstalledApp) { NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in } }
    func move(_ id: String, to target: String) {
        guard id != target else { return }
        // Dropping on an icon creates a folder, as in Launchpad. Existing folders accept more apps.
        if let folder = layout.folders.firstIndex(where: { $0.id == target }) {
            layout.folders[folder].appIDs.removeAll { $0 == id }; layout.folders[folder].appIDs.append(id)
        } else if let existing = layout.folders.firstIndex(where: { $0.appIDs.contains(target) }) {
            if !layout.folders[existing].appIDs.contains(id) { layout.folders[existing].appIDs.append(id) }
        } else if let f = layout.folders.firstIndex(where: { $0.appIDs.contains(id) }) {
            layout.folders[f].appIDs.removeAll { $0 == id }; layout.folders[f].appIDs.append(target)
            if layout.folders[f].appIDs.count < 2 { layout.folders.remove(at: f) }
            layout.order.removeAll { $0 == id }
        } else {
            layout.folders.append(AppFolder(name: "文件夹", appIDs: [target, id]))
            layout.order.removeAll { $0 == id || $0 == target }; layout.order.insert(target, at: min(layout.order.count, layout.order.count))
        }
    }
    func reorder(_ id: String, before target: String) {
        guard id != target, !layout.folders.contains(where: { $0.appIDs.contains(id) }) else { return }
        layout.order.removeAll { $0 == id }
        let i = layout.order.firstIndex(of: target) ?? layout.order.endIndex; layout.order.insert(id, at: i)
    }
    func reorderAfter(_ id: String, target: String) {
        guard id != target, !layout.folders.contains(where: { $0.appIDs.contains(id) }) else { return }
        layout.order.removeAll { $0 == id }
        let i = layout.order.firstIndex(of: target).map { $0 + 1 } ?? layout.order.endIndex
        layout.order.insert(id, at: min(i, layout.order.endIndex))
    }
    func renameFolder(_ id: String, _ name: String) { if let i = layout.folders.firstIndex(where: { $0.id == id }) { layout.folders[i].name = name } }
    func removeFromFolder(_ appID: String, folderID: String) {
        guard let i = layout.folders.firstIndex(where: { $0.id == folderID }) else { return }
        layout.folders[i].appIDs.removeAll { $0 == appID }; if layout.folders[i].appIDs.count < 2 { layout.folders.remove(at: i) }
        layout.order.append(appID)
    }
}

struct LaunchpadView: View {
    @StateObject private var catalog = AppCatalog()
    @State private var openFolder: String?
    @State private var renameFolder: String?
    @State private var folderName = ""
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 6)
    private var folderContents: [InstalledApp] { guard let f = catalog.layout.folders.first(where: { $0.id == openFolder }) else { return [] }; return f.appIDs.compactMap(catalog.app) }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 26) {
                ForEach(catalog.layout.order, id: \.self) { id in
                    if let folder = catalog.layout.folders.first(where: { $0.appIDs.contains(id) }) {
                        if folder.appIDs.first == id { folderTile(folder) }
                    } else if let app = catalog.app(id) { appTile(app) }
                }
            }.padding(.horizontal, 42).padding(.top, 36).padding(.bottom, 30)
        }
        .background(background.ignoresSafeArea())
        .background(.ultraThinMaterial.opacity(0.16))
        .task { catalog.refresh() }
        .sheet(isPresented: Binding(get: { openFolder != nil }, set: { if !$0 { openFolder = nil } })) { folderSheet }
        .alert("重命名文件夹", isPresented: Binding(get: { renameFolder != nil }, set: { if !$0 { renameFolder = nil } })) {
            TextField("文件夹名称", text: $folderName)
            Button("取消", role: .cancel) { renameFolder = nil }
            Button("完成") { if let id = renameFolder { catalog.renameFolder(id, folderName) }; renameFolder = nil }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.22), Color(red: 0.07, green: 0.08, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color.blue.opacity(0.17)).frame(width: 420).blur(radius: 100).offset(x: -280, y: -250)
            Circle().fill(Color.purple.opacity(0.12)).frame(width: 380).blur(radius: 100).offset(x: 340, y: 220)
        }
    }
    private func appTile(_ app: InstalledApp) -> some View {
        VStack(spacing: 9) {
            Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: 66, height: 66).shadow(color: .black.opacity(0.28), radius: 10, y: 6)
            Text(app.name).font(.system(size: 12)).lineLimit(1).foregroundStyle(.white.opacity(0.92)).frame(maxWidth: 104)
        }.frame(maxWidth: .infinity).contentShape(Rectangle())
            .onTapGesture { catalog.open(app) }
            .onDrag { NSItemProvider(object: app.id as NSString) }
            .onDrop(of: [.text], delegate: AppTileDropDelegate(target: app.id, catalog: catalog, width: 104))
            .contextMenu { Button("從文件夾移出") { if let f = catalog.layout.folders.first(where: { $0.appIDs.contains(app.id) }) { catalog.removeFromFolder(app.id, folderID: f.id) } } }
    }
    private func folderTile(_ folder: AppFolder) -> some View {
        VStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 17).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.2), lineWidth: 1))
                LazyVGrid(columns: [GridItem(.fixed(21)), GridItem(.fixed(21)), GridItem(.fixed(21))], spacing: 2) {
                    ForEach(folder.appIDs.prefix(9), id: \.self) { id in if let app = catalog.app(id) { Image(nsImage: app.icon).resizable().frame(width: 21, height: 21).clipShape(RoundedRectangle(cornerRadius: 5)) } }
                }.padding(10)
            }.frame(width: 66, height: 66)
            Text(folder.name).font(.system(size: 12)).lineLimit(1).foregroundStyle(.white.opacity(0.92)).frame(maxWidth: 104)
        }.frame(maxWidth: .infinity).contentShape(Rectangle())
            .onTapGesture { openFolder = folder.id }
            .onDrag { NSItemProvider(object: folder.id as NSString) }
            .onDrop(of: [.text], delegate: AppTileDropDelegate(target: folder.id, catalog: catalog, width: 104))
            .contextMenu { Button("重命名") { folderName = folder.name; renameFolder = folder.id } }
    }
    private var folderSheet: some View {
        VStack(spacing: 18) {
            HStack { Text(catalog.layout.folders.first(where: { $0.id == openFolder })?.name ?? "文件夹").font(.title2.weight(.semibold)); Spacer(); Button { if let f = catalog.layout.folders.first(where: { $0.id == openFolder }) { folderName = f.name; renameFolder = f.id; openFolder = nil } } label: { Image(systemName: "pencil") }.buttonStyle(.plain) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 22) { ForEach(folderContents) { app in appTile(app) } }
        }.padding(26).frame(minWidth: 420, minHeight: 260).background(background)
    }
}

struct AppTileDropDelegate: DropDelegate {
    let target: String
    let catalog: AppCatalog
    let width: CGFloat

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.text]) }
    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        let x = info.location.x
        _ = provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let source = value as? NSString else { return }
            let sourceID = source as String
            DispatchQueue.main.async {
                if catalog.layout.folders.contains(where: { $0.id == target }) {
                    catalog.move(sourceID, to: target)
                } else if x < width * 0.28 {
                    catalog.reorder(sourceID, before: target)
                } else if x > width * 0.72 {
                    catalog.reorderAfter(sourceID, target: target)
                } else {
                    catalog.move(sourceID, to: target)
                }
            }
        }
        return true
    }
}
