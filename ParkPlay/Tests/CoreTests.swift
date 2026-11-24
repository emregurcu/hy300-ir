import XCTest
@testable import ParkPlayCore

final class CoreTests: XCTestCase {
    let sid = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func testM3UParsesAttributesTitlesAndGroups() {
        let text = """
        #EXTM3U url-tvg="http://epg"
        #EXTINF:-1 tvg-id="trt1" tvg-logo="http://x/logo.png" group-title="Ulusal, HD",TRT 1 HD
        #EXTVLCOPT:http-user-agent=Foo
        http://host/trt1.m3u8
        #EXTINF:-1,Belgesel, Doğa\r
        #EXTGRP:Belgesel\r
        http://host/doga.m3u8\r

        #EXTINF:0 tvg-name="Film A" group-title="Filmler",
        http://host/a.mkv
        not a url
        http://host/trt1.m3u8
        """
        let items = M3UParser.parse(text, sourceID: sid)
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[0].title, "TRT 1 HD")
        XCTAssertEqual(items[0].group, "Ulusal, HD")
        XCTAssertEqual(items[0].logo?.absoluteString, "http://x/logo.png")
        XCTAssertTrue(items[0].isLive)
        XCTAssertEqual(items[1].title, "Belgesel, Doğa")
        XCTAssertEqual(items[1].group, "Belgesel")
        XCTAssertEqual(items[2].title, "Film A")
        XCTAssertFalse(items[2].isLive)
        XCTAssertEqual(items[3].title, "trt1.m3u8")
        XCTAssertEqual(Set(items.map(\.id)).count, 4, "kimlikler benzersiz olmalı")
    }

    func testXtreamURLsAndStreamParsing() throws {
        let client = XtreamClient(base: "host.tv:8080/".normalizedServerURL!, username: "u", password: "p", sourceID: sid)
        XCTAssertEqual(client.apiURL(action: "get_live_streams").absoluteString,
                       "http://host.tv:8080/player_api.php?username=u&password=p&action=get_live_streams")
        let cats = XtreamClient.categoryNames(Data(#"[{"category_id":"7","category_name":"Spor"}]"#.utf8))
        let json = #"[{"name":"A","stream_id":12,"stream_icon":"","category_id":"7"},{"name":"B","stream_id":"13","category_id":null}]"#
        let live = try client.parseStreams(Data(json.utf8), categories: cats, live: true)
        XCTAssertEqual(live.map(\.url.absoluteString), ["http://host.tv:8080/live/u/p/12.m3u8", "http://host.tv:8080/live/u/p/13.m3u8"])
        XCTAssertEqual(live.map(\.group), ["Spor", "Diğer"])
        let movie = try client.parseStreams(Data(#"[{"name":"F","stream_id":5,"container_extension":"mkv"}]"#.utf8), categories: [:], live: false)
        XCTAssertEqual(movie[0].url.absoluteString, "http://host.tv:8080/movie/u/p/5.mkv")
        XCTAssertFalse(movie[0].isLive)
        XCTAssertThrowsError(try client.parseStreams(Data(#"{"user_info":{"auth":0}}"#.utf8), categories: [:], live: true))
    }

    func testJellyfinEntriesAndStreamURL() throws {
        let json = #"{"Items":[{"Id":"a","Name":"Filmler","IsFolder":true,"Type":"CollectionFolder"},{"Id":"b","Name":"Pilot","IsFolder":false,"Type":"Episode","IndexNumber":1,"ImageTags":{"Primary":"t"}},{"Id":"c","Name":"Şarkı","IsFolder":false,"Type":"Audio"}]}"#
        let entries = try JellyfinClient.parseEntries(Data(json.utf8))
        XCTAssertEqual(entries.map(\.id), ["a", "b"])
        XCTAssertEqual(entries[1].subtitle, "Bölüm 1")
        XCTAssertTrue(entries[1].hasImage)

        let client = JellyfinClient(base: "https://jf.example.com".normalizedServerURL!, deviceID: "dev")
        let url = client.streamURL(itemID: "b")
        XCTAssertTrue(url.absoluteString.hasPrefix("https://jf.example.com/Videos/b/master.m3u8?MediaSourceId=b"))
        XCTAssertFalse(url.absoluteString.contains("api_key"))
        XCTAssertTrue(JellyfinClient.authorized(url, token: "tok").absoluteString.hasSuffix("&api_key=tok"))
    }

    func testServerURLNormalization() {
        XCTAssertEqual("  https://a.b/ ".normalizedServerURL?.absoluteString, "https://a.b")
        XCTAssertEqual("192.168.1.5:8096".normalizedServerURL?.absoluteString, "http://192.168.1.5:8096")
        XCTAssertNil("".normalizedServerURL)
    }
}
