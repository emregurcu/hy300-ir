import Foundation

enum SourceKind: String, Codable, CaseIterable, Identifiable {
    case m3u, xtream, jellyfin
    var id: String { rawValue }
    var title: String {
        switch self {
        case .m3u: return "M3U listesi"
        case .xtream: return "Xtream Codes"
        case .jellyfin: return "Jellyfin"
        }
    }
}

/// Kullanıcının eklediği bir kaynak. Parola / erişim anahtarı burada değil, Anahtar Zinciri'nde tutulur.
struct MediaSource: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: SourceKind
    /// M3U için liste adresi, diğerleri için sunucu adresi.
    var url: String
    var username: String = ""
    /// Jellyfin kullanıcı kimliği (girişten sonra dolar).
    var userID: String = ""
}

struct MediaItem: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var group: String = ""
    var logo: URL?
    var url: URL
    var isLive: Bool = false
    /// Oynatma anında kimlik bilgisi eklenmesi gereken kaynak (Jellyfin).
    var sourceID: UUID?
}

enum MediaError: LocalizedError, Equatable {
    case badURL
    case http(Int)
    case badResponse
    case auth
    case emptyPlaylist

    var errorDescription: String? {
        switch self {
        case .badURL: return "Adres geçersiz."
        case .http(let code): return "Sunucu hata döndürdü (HTTP \(code))."
        case .badResponse: return "Sunucudan beklenmeyen bir yanıt geldi."
        case .auth: return "Kullanıcı adı veya parola hatalı."
        case .emptyPlaylist: return "Listede oynatılabilir bir kanal bulunamadı."
        }
    }
}

extension String {
    /// "sunucu.com:8080" gibi girişleri tam bir adrese çevirir, sondaki / işaretini atar.
    var normalizedServerURL: URL? {
        var text = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "http://" + text
        }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), url.host != nil else { return nil }
        return url
    }
}
