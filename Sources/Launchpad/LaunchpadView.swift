import AppKit
import SwiftUI

struct InstalledApp: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleID: String
    var id: String { bundleID.isEmpty ? url.path : bundleID }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

@MainActor
final class AppCatalog: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    @Published var isLoading = false

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let roots = [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"), URL(fileURLWithPath: "/System/Applications/Utilities"), FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications")]
            var found: [String: InstalledApp] = [:]
            for root in roots {
                guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isApplicationKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
                for case let url as URL in enumerator where url.pathExtension == "app" {
                    let values = try? url.resourceValues(forKeys: [.isApplicationKey])
                    guard values?.isApplication == true else { continue }
                    let bundle = Bundle(url: url)
                    let id = bundle?.bundleIdentifier ?? url.path
                    let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                        ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                        ?? url.deletingPathExtension().lastPathComponent
                    found[id] = InstalledApp(url: url, name: name, bundleID: id)
                    enumerator.skipDescendants()
                }
            }
            let result = found.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            await MainActor.run { self.apps = result; self.isLoading = false }
        }
    }

    func open(_ app: InstalledApp) {
        NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }
}

struct LaunchpadView: View {
    @StateObject private var catalog = AppCatalog()
    @State private var search = ""
    @State private var category = "全部"
    @FocusState private var searchFocused: Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 6)
    private let categories = ["全部", "系统", "实用工具", "其他"]

    private var visibleApps: [InstalledApp] {
        catalog.apps.filter { app in
            (search.isEmpty || app.name.localizedCaseInsensitiveContains(search) || app.bundleID.localizedCaseInsensitiveContains(search)) &&
            (category == "全部" || categoryMatches(app))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField.padding(.top, 32)
            categoryPicker.padding(.top, 18)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(visibleApps) { app in
                        Button { catalog.open(app) } label: {
                            VStack(spacing: 9) {
                                Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: 66, height: 66)
                                    .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
                                Text(app.name).font(.system(size: 12)).lineLimit(1).truncationMode(.tail)
                                    .foregroundStyle(.white.opacity(0.9)).frame(maxWidth: 100)
                            }.frame(maxWidth: .infinity).contentShape(Rectangle())
                        }.buttonStyle(.plain).help("打开 \(app.name)")
                    }
                }.padding(.horizontal, 34).padding(.top, 22).padding(.bottom, 28)
                if visibleApps.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "没有找到应用" : "没有匹配的应用", systemImage: "app.dashed")
                        .padding(.top, 70)
                }
            }
            footer
        }
        .background {
            ZStack {
                LinearGradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.22), Color(red: 0.07, green: 0.08, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color.blue.opacity(0.17)).frame(width: 420).blur(radius: 100).offset(x: -280, y: -250)
                Circle().fill(Color.purple.opacity(0.12)).frame(width: 380).blur(radius: 100).offset(x: 340, y: 220)
            }.ignoresSafeArea()
        }
        .task { catalog.refresh() }
        .onKeyPress(.escape) { search = ""; searchFocused = false; return .handled }
        .background(.ultraThinMaterial.opacity(0.18))
    }

    private var header: some View {
        HStack {
            Label("Launchpad", systemImage: "square.grid.3x3.fill").font(.system(size: 14, weight: .semibold))
            Spacer()
            Text("⌘ K").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 8).padding(.vertical, 5).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }.padding(.horizontal, 26).padding(.top, 20)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.55))
            TextField("搜索应用…", text: $search).textFieldStyle(.plain).focused($searchFocused)
                .onSubmit { if let first = visibleApps.first { catalog.open(first) } }
            if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.5)) }.buttonStyle(.plain) }
        }.font(.system(size: 14)).padding(.horizontal, 16).frame(height: 48)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 90)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in }
    }

    private var categoryPicker: some View {
        HStack(spacing: 4) {
            ForEach(categories, id: \.self) { item in
                Button { category = item } label: {
                    Text(item).font(.system(size: 12, weight: category == item ? .medium : .regular))
                        .foregroundStyle(category == item ? .white : .white.opacity(0.58))
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(category == item ? .white.opacity(0.14) : .clear, in: Capsule())
                }.buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack { Text("\(visibleApps.count) 个应用"); Spacer(); if catalog.isLoading { ProgressView().controlSize(.small) }; Button { catalog.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).help("重新扫描应用") }
            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.48)).padding(.horizontal, 26).padding(.vertical, 13)
            .background(.ultraThinMaterial.opacity(0.25))
    }

    private func categoryMatches(_ app: InstalledApp) -> Bool {
        let p = app.url.path
        if category == "系统" { return p.hasPrefix("/System/Applications/") && !p.contains("/Utilities/") }
        if category == "实用工具" { return p.contains("/Utilities/") }
        return !p.hasPrefix("/System/Applications/")
    }
}
