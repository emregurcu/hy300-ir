import Foundation

/// Xtream Codes "player_api.php" istemcisi: canlı kanallar ve filmler.
struct XtreamClient {
    let base: URL
    let username: String
    let password: String
    let sourceID: UUID

    func apiURL(action: String) -> URL {
        var parts = URLComponents(url: base.appendingPathComponent("player_api.php"), resolvingAgainstBaseURL: false)!
        parts.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "action", value: action),
        ]
        return parts.url!
    }

    /// Canlı yayınlar HLS (.m3u8) olarak istenir; iOS oynatıcısı ham MPEG-TS akışını açamaz.
    func liveURL(streamID: String) -> URL {
        base.appendingPathComponent("live/\(username)/\(password)/\(streamID).m3u8")
    }

    func movieURL(streamID: String, ext: String) -> URL {
        base.appendingPathComponent("movie/\(username)/\(password)/\(streamID).\(ext.isEmpty ? "mp4" : ext)")
    }

    func loadAll() async throws -> [MediaItem] {
        async let live = load(categories: "get_live_categories", streams: "get_live_streams", live: true)
        async let movies = load(categories: "get_vod_categories", streams: "get_vod_streams", live: false)
        let liveItems = try await live
        // Bazı sağlayıcılarda film bölümü yoktur; canlı kanallar geldiyse bunu hata saymayız.
        let movieItems = (try? await movies) ?? []
        let all = liveItems + movieItems
        if all.isEmpty { throw MediaError.emptyPlaylist }
        return all
    }

    private func load(categories: String, streams: String, live: Bool) async throws -> [MediaItem] {
        async let categoryData = HTTP.get(apiURL(action: categories))
        async let streamData = HTTP.get(apiURL(action: streams))
        let names = Self.categoryNames(try await categoryData)
        return try parseStreams(try await streamData, categories: names, live: live)
    }

    static func categoryNames(_ data: Data) -> [String: String] {
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [:] }
        var names: [String: String] = [:]
        for row in rows {
            if let id = text(row["category_id"]), let name = text(row["category_name"]) { names[id] = name }
        }
        return names
    }

    func parseStreams(_ data: Data, categories: [String: String], live: Bool) throws -> [MediaItem] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Hatalı girişte sunucu dizi yerine {"user_info": {"auth": 0}} döndürür.
            throw MediaError.auth
        }
        return rows.compactMap { row in
            guard let streamID = Self.text(row["stream_id"]), let name = Self.text(row["name"]) else { return nil }
            let category = Self.text(row["category_id"]).flatMap { categories[$0] } ?? ""
            let logo = Self.text(row["stream_icon"]).flatMap { $0.isEmpty ? nil : URL(string: $0) }
            let url = live ? liveURL(streamID: streamID)
                           : movieURL(streamID: streamID, ext: Self.text(row["container_extension"]) ?? "")
            return MediaItem(
                id: "xt:\(sourceID.uuidString):\(live ? "live" : "movie"):\(streamID)",
                title: name,
                group: (live ? "" : "Film · ") + (category.isEmpty ? "Diğer" : category),
                logo: logo, url: url, isLive: live)
        }
    }

    /// Xtream sunucuları aynı alanı bazen sayı bazen metin olarak yollar.
    private static func text(_ value: Any?) -> String? {
        switch value {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }
}
