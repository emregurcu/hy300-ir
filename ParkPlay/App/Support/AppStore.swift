import Foundation
import Observation

/// Uygulamanın tüm kalıcı durumu: kaynaklar, favoriler, kaldığı yerler.
/// Hiçbir veri cihaz dışına gönderilmez; analiz veya reklam kodu yoktur.
@MainActor
@Observable
final class AppStore {
    private struct Saved: Codable {
        var sources: [MediaSource] = []
        var favorites: [MediaItem] = []
        var resume: [String: Double] = [:]
        var deviceID = UUID().uuidString
    }

    private(set) var sources: [MediaSource] = []
    private(set) var favorites: [MediaItem] = []
    private var resume: [String: Double] = [:]
    private var deviceID = UUID().uuidString

    /// Bu oturumda indirilen kanal listeleri.
    @ObservationIgnored private var cache: [UUID: [MediaItem]] = [:]

    private let fileURL: URL = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("parkplay.json")
    }()

    init() {
        if let data = try? Data(contentsOf: fileURL), let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            sources = saved.sources
            favorites = saved.favorites
            resume = saved.resume
            deviceID = saved.deviceID
        }
    }

    private func save() {
        let saved = Saved(sources: sources, favorites: favorites, resume: resume, deviceID: deviceID)
        if let data = try? JSONEncoder().encode(saved) { try? data.write(to: fileURL, options: .atomic) }
    }

    // MARK: Kaynaklar

    /// Kaynağı doğrular (liste iner / giriş yapılır) ve başarılıysa kaydeder.
    func add(_ draft: MediaSource, password: String) async throws {
        var source = draft
        switch source.kind {
        case .m3u:
            guard let url = URL(string: source.url.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme != nil
            else { throw MediaError.badURL }
            source.url = url.absoluteString
            cache[source.id] = try await M3UParser.load(from: url, sourceID: source.id)
        case .xtream:
            guard let base = source.url.normalizedServerURL else { throw MediaError.badURL }
            source.url = base.absoluteString
            let client = XtreamClient(base: base, username: source.username, password: password, sourceID: source.id)
            cache[source.id] = try await client.loadAll()
            Keychain.set(password, for: source.id.uuidString)
        case .jellyfin:
            guard let base = source.url.normalizedServerURL else { throw MediaError.badURL }
            source.url = base.absoluteString
            let result = try await JellyfinClient(base: base, deviceID: deviceID)
                .signIn(username: source.username, password: password)
            source.userID = result.userID
            // Jellyfin için parola saklanmaz, yalnızca sunucunun verdiği erişim anahtarı saklanır.
            Keychain.set(result.token, for: source.id.uuidString)
        }
        sources.append(source)
        save()
    }

    func remove(_ source: MediaSource) {
        sources.removeAll { $0.id == source.id }
        favorites.removeAll { $0.id.contains(source.id.uuidString) }
        cache[source.id] = nil
        Keychain.delete(source.id.uuidString)
        save()
    }

    func items(for source: MediaSource, refresh: Bool = false) async throws -> [MediaItem] {
        if !refresh, let cached = cache[source.id] { return cached }
        let items: [MediaItem]
        switch source.kind {
        case .m3u:
            guard let url = URL(string: source.url) else { throw MediaError.badURL }
            items = try await M3UParser.load(from: url, sourceID: source.id)
        case .xtream:
            guard let base = URL(string: source.url) else { throw MediaError.badURL }
            items = try await XtreamClient(base: base, username: source.username,
                                           password: Keychain.get(source.id.uuidString), sourceID: source.id).loadAll()
        case .jellyfin:
            items = []
        }
        cache[source.id] = items
        return items
    }

    func jellyfin(for source: MediaSource) -> JellyfinClient? {
        guard let base = URL(string: source.url) else { return nil }
        return JellyfinClient(base: base, deviceID: deviceID,
                              token: Keychain.get(source.id.uuidString), userID: source.userID)
    }

    /// Oynatıcıya verilecek adres. Jellyfin öğelerine erişim anahtarı burada eklenir.
    func playableURL(for item: MediaItem) -> URL {
        // Uygulama güncellenince klasör yolu değişebilir; yerel dosyaların yolu her seferinde yeniden kurulur.
        if item.id.hasPrefix("local:") { return LocalLibrary.folder.appendingPathComponent(item.url.lastPathComponent) }
        guard let sourceID = item.sourceID else { return item.url }
        return JellyfinClient.authorized(item.url, token: Keychain.get(sourceID.uuidString))
    }

    // MARK: Favoriler

    func isFavorite(_ item: MediaItem) -> Bool { favorites.contains { $0.id == item.id } }

    func toggleFavorite(_ item: MediaItem) {
        if isFavorite(item) { favorites.removeAll { $0.id == item.id } } else { favorites.append(item) }
        save()
    }

    // MARK: Kaldığı yerden devam

    func resumePosition(for item: MediaItem) -> Double { resume[item.id] ?? 0 }

    func setResume(_ seconds: Double, duration: Double, for item: MediaItem) {
        guard !item.isLive, duration > 60 else { return }
        // Başta veya sonda ise kayıt tutmaya gerek yok.
        resume[item.id] = (seconds < 15 || seconds > duration * 0.95) ? nil : seconds
        save()
    }
}
