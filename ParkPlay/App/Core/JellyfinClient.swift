import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct JellyfinEntry: Identifiable, Hashable {
    var id: String
    var name: String
    var isFolder: Bool
    var subtitle: String
    var hasImage: Bool
}

struct JellyfinClient {
    let base: URL
    let deviceID: String
    var token: String = ""
    var userID: String = ""

    private var authHeader: String {
        var value = "MediaBrowser Client=\"ParkPlay\", Device=\"iPhone\", DeviceId=\"\(deviceID)\", Version=\"1.0\""
        if !token.isEmpty { value += ", Token=\"\(token)\"" }
        return value
    }

    /// Giriş yapar; erişim anahtarını ve kullanıcı kimliğini döndürür.
    func signIn(username: String, password: String) async throws -> (token: String, userID: String) {
        var request = URLRequest(url: base.appendingPathComponent("Users/AuthenticateByName"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["Username": username, "Pw": password])
        let data = try await HTTP.send(request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["AccessToken"] as? String,
              let user = json["User"] as? [String: Any], let userID = user["Id"] as? String
        else { throw MediaError.badResponse }
        return (token, userID)
    }

    /// parentID boşsa kütüphanelerin listesi, doluysa o klasörün içeriği gelir.
    func entries(parentID: String?) async throws -> [JellyfinEntry] {
        let url: URL
        if let parentID {
            var parts = URLComponents(url: base.appendingPathComponent("Users/\(userID)/Items"), resolvingAgainstBaseURL: false)!
            parts.queryItems = [
                URLQueryItem(name: "ParentId", value: parentID),
                URLQueryItem(name: "SortBy", value: "IsFolder,ParentIndexNumber,IndexNumber,SortName"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
            ]
            url = parts.url!
        } else {
            url = base.appendingPathComponent("Users/\(userID)/Views")
        }
        return try Self.parseEntries(try await HTTP.get(url, headers: ["Authorization": authHeader]))
    }

    static func parseEntries(_ data: Data) throws -> [JellyfinEntry] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = json["Items"] as? [[String: Any]] else { throw MediaError.badResponse }
        return rows.compactMap { row in
            guard let id = row["Id"] as? String, let name = row["Name"] as? String else { return nil }
            let type = row["Type"] as? String ?? ""
            let isFolder = (row["IsFolder"] as? Bool) ?? false
            // Müzik, kitap vb. bu sürümde oynatılmıyor.
            guard isFolder || ["Movie", "Episode", "Video", "MusicVideo"].contains(type) else { return nil }
            var subtitle = ""
            if type == "Episode", let number = row["IndexNumber"] as? Int { subtitle = "Bölüm \(number)" }
            else if let year = row["ProductionYear"] as? Int { subtitle = String(year) }
            let images = row["ImageTags"] as? [String: Any]
            return JellyfinEntry(id: id, name: name, isFolder: isFolder, subtitle: subtitle, hasImage: images?["Primary"] != nil)
        }
    }

    func imageURL(itemID: String) -> URL {
        var parts = URLComponents(url: base.appendingPathComponent("Items/\(itemID)/Images/Primary"), resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "maxHeight", value: "240")]
        return parts.url!
    }

    /// Sunucudan HLS ister: MKV, DTS gibi iOS'un açamadığı biçimleri sunucu çevirir.
    /// Erişim anahtarı adrese burada eklenmez; oynatma anında `authorized(_:token:)` ile eklenir.
    func streamURL(itemID: String) -> URL {
        var parts = URLComponents(url: base.appendingPathComponent("Videos/\(itemID)/master.m3u8"), resolvingAgainstBaseURL: false)!
        parts.queryItems = [
            URLQueryItem(name: "MediaSourceId", value: itemID),
            URLQueryItem(name: "DeviceId", value: deviceID),
            URLQueryItem(name: "VideoCodec", value: "h264"),
            URLQueryItem(name: "AudioCodec", value: "aac"),
            URLQueryItem(name: "VideoBitrate", value: "8000000"),
            URLQueryItem(name: "AudioBitrate", value: "192000"),
            URLQueryItem(name: "TranscodingMaxAudioChannels", value: "2"),
            URLQueryItem(name: "SegmentContainer", value: "ts"),
        ]
        return parts.url!
    }

    static func authorized(_ url: URL, token: String) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        parts.queryItems = (parts.queryItems ?? []) + [URLQueryItem(name: "api_key", value: token)]
        return parts.url ?? url
    }
}
