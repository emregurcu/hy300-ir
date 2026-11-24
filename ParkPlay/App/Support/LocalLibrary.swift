import Foundation

/// Uygulamaya aktarılan videolar (Belgeler/Videolar). Dosyalar uygulamasından da görünür.
enum LocalLibrary {
    static let folder: URL = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Videolar", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func items() -> [MediaItem] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                                 options: .skipsHiddenFiles)) ?? []
        return urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { MediaItem(id: "local:\($0.lastPathComponent)", title: $0.deletingPathExtension().lastPathComponent,
                             group: "Dosyalar", url: $0) }
    }

    /// Seçilen dosyaları uygulamanın klasörüne kopyalar. Kopyalanamayanların adlarını döndürür.
    static func importFiles(_ urls: [URL]) -> [String] {
        var failed: [String] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let target = folder.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
                try FileManager.default.copyItem(at: url, to: target)
            } catch {
                failed.append(url.lastPathComponent)
            }
        }
        return failed
    }

    static func delete(_ item: MediaItem) {
        try? FileManager.default.removeItem(at: item.url)
    }
}
