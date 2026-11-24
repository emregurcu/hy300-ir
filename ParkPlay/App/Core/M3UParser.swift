import Foundation

enum M3UParser {
    private static let attribute = try! NSRegularExpression(pattern: "([A-Za-z0-9_-]+)=\"([^\"]*)\"")

    static func load(from url: URL, sourceID: UUID) async throws -> [MediaItem] {
        let data = try await HTTP.get(url)
        let items = parse(String(decoding: data, as: UTF8.self), sourceID: sourceID)
        if items.isEmpty { throw MediaError.emptyPlaylist }
        return items
    }

    static func parse(_ text: String, sourceID: UUID) -> [MediaItem] {
        var items: [MediaItem] = []
        var seen: [String: Int] = [:]
        var title: String?
        var group = ""
        var logo: URL?

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("#EXTINF") {
                let info = parseInfo(line)
                title = info.title
                group = info.attributes["group-title"] ?? ""
                logo = info.attributes["tvg-logo"].flatMap { $0.isEmpty ? nil : URL(string: $0) }
                if title?.isEmpty ?? true { title = info.attributes["tvg-name"] }
            } else if line.hasPrefix("#EXTGRP:") {
                if group.isEmpty { group = String(line.dropFirst("#EXTGRP:".count)).trimmingCharacters(in: .whitespaces) }
            } else if line.hasPrefix("#") {
                continue
            } else if let url = URL(string: line), url.scheme != nil {
                // Aynı adres listede iki kez geçerse kimlikler çakışmasın.
                let count = seen[line, default: 0]
                seen[line] = count + 1
                let id = "m3u:\(sourceID.uuidString):\(line)" + (count > 0 ? "#\(count)" : "")
                let name = (title?.isEmpty == false ? title! : url.lastPathComponent)
                items.append(MediaItem(id: id, title: name, group: group, logo: logo, url: url, isLive: isLive(url)))
                title = nil; group = ""; logo = nil
            }
        }
        return items
    }

    /// Dosya uzantısı film gibi görünüyorsa canlı yayın saymayız (kaldığı yerden devam için).
    private static func isLive(_ url: URL) -> Bool {
        !["mp4", "mkv", "mov", "m4v", "avi"].contains(url.pathExtension.lowercased())
    }

    private static func parseInfo(_ line: String) -> (title: String, attributes: [String: String]) {
        // Başlık, tırnak dışındaki ilk virgülden sonrasıdır.
        var inQuotes = false
        var splitIndex: String.Index?
        for index in line.indices {
            let ch = line[index]
            if ch == "\"" { inQuotes.toggle() }
            else if ch == "," && !inQuotes { splitIndex = index; break }
        }
        let head = splitIndex.map { String(line[..<$0]) } ?? line
        let title = splitIndex.map { String(line[line.index(after: $0)...]).trimmingCharacters(in: .whitespaces) } ?? ""

        var attributes: [String: String] = [:]
        let ns = head as NSString
        for match in attribute.matches(in: head, range: NSRange(location: 0, length: ns.length)) {
            attributes[ns.substring(with: match.range(at: 1)).lowercased()] = ns.substring(with: match.range(at: 2))
        }
        return (title, attributes)
    }
}
