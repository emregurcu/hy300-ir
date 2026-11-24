import SwiftUI

struct SourcesView: View {
    @Environment(AppStore.self) private var store
    let play: PlayAction
    @State private var adding = false

    var body: some View {
        NavigationStack {
            Group {
                if store.sources.isEmpty {
                    ContentUnavailableView {
                        Label("Kaynak ekleyin", systemImage: "tv")
                    } description: {
                        Text("M3U listesi, Xtream hesabı veya Jellyfin sunucusu ekleyebilirsiniz. ParkPlay içerik sağlamaz.")
                    } actions: {
                        Button("Kaynak ekle") { adding = true }.buttonStyle(.borderedProminent).controlSize(.large)
                    }
                } else {
                    List {
                        ForEach(store.sources) { source in
                            NavigationLink(value: source) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.name).font(.title3.bold())
                                    Text(source.kind.title).font(.subheadline).foregroundStyle(.secondary)
                                }
                                .frame(minHeight: 56)
                            }
                        }
                        .onDelete { offsets in offsets.map { store.sources[$0] }.forEach { store.remove($0) } }
                    }
                }
            }
            .navigationTitle("ParkPlay")
            .toolbar {
                Button { adding = true } label: { Label("Kaynak ekle", systemImage: "plus") }
            }
            .navigationDestination(for: MediaSource.self) { source in
                if source.kind == .jellyfin {
                    JellyfinFolderView(source: source, folder: nil, play: play)
                } else {
                    ChannelListView(source: source, play: play)
                }
            }
            .navigationDestination(for: JellyfinFolder.self) { folder in
                JellyfinFolderView(source: folder.source, folder: folder, play: play)
            }
            .sheet(isPresented: $adding) { AddSourceView() }
        }
    }
}

struct AddSourceView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kind = SourceKind.m3u
    @State private var name = ""
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var working = false
    @State private var error: String?

    private var canSave: Bool {
        !url.trimmingCharacters(in: .whitespaces).isEmpty && (kind == .m3u || !username.isEmpty) && !working
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tür", selection: $kind) {
                    ForEach(SourceKind.allCases) { Text($0.title).tag($0) }
                }
                Section {
                    TextField("Ad (isteğe bağlı)", text: $name)
                    TextField(kind == .m3u ? "Liste adresi (https://…/liste.m3u)" : "Sunucu adresi", text: $url)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if kind == .m3u {
                        PasteButton(payloadType: String.self) { strings in
                            if let first = strings.first { url = first }
                        }
                    } else {
                        TextField("Kullanıcı adı", text: $username)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Parola", text: $password)
                    }
                } footer: {
                    Text("Bilgileriniz yalnızca bu cihazda, Anahtar Zinciri'nde saklanır.")
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Kaynak ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if working { ProgressView() } else { Button("Ekle", action: save).disabled(!canSave) }
                }
            }
        }
    }

    private func save() {
        working = true
        error = nil
        let host = url.normalizedServerURL?.host ?? ""
        let title = name.trimmingCharacters(in: .whitespaces)
        let source = MediaSource(name: title.isEmpty ? (host.isEmpty ? kind.title : host) : title,
                                 kind: kind, url: url, username: kind == .m3u ? "" : username)
        Task {
            do {
                try await store.add(source, password: password)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            working = false
        }
    }
}

/// M3U ve Xtream kaynakları: gruplar, arama, kanal listesi.
struct ChannelListView: View {
    @Environment(AppStore.self) private var store
    let source: MediaSource
    let play: PlayAction
    @State private var items: [MediaItem] = []
    @State private var groups: [String] = []
    @State private var selectedGroup: String?
    @State private var search = ""
    @State private var loading = true
    @State private var error: String?

    private var visible: [MediaItem] {
        var list = items
        if let selectedGroup { list = list.filter { $0.group == selectedGroup } }
        if !search.isEmpty { list = list.filter { $0.title.localizedCaseInsensitiveContains(search) } }
        return list
    }

    var body: some View {
        Group {
            if loading {
                ProgressView("Yükleniyor…").controlSize(.large)
            } else if let error {
                ContentUnavailableView {
                    Label("Yüklenemedi", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Yeniden dene") { Task { await load(refresh: true) } }.buttonStyle(.borderedProminent)
                }
            } else {
                let list = visible
                List(list) { item in
                    MediaRow(item: item) { play(item, list) }
                }
                .overlay {
                    if list.isEmpty { ContentUnavailableView.search(text: search) }
                }
            }
        }
        .navigationTitle(selectedGroup ?? source.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Kanal ara")
        .toolbar {
            Menu {
                Picker("Grup", selection: $selectedGroup) {
                    Text("Tümü").tag(String?.none)
                    ForEach(groups, id: \.self) { Text($0.isEmpty ? "Grupsuz" : $0).tag(String?.some($0)) }
                }
                Button { Task { await load(refresh: true) } } label: { Label("Listeyi yenile", systemImage: "arrow.clockwise") }
            } label: {
                Label("Grup", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
        .task { await load(refresh: false) }
    }

    private func load(refresh: Bool) async {
        loading = true
        error = nil
        do {
            items = try await store.items(for: source, refresh: refresh)
            var seen = Set<String>()
            groups = items.map(\.group).filter { seen.insert($0).inserted }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct JellyfinFolder: Hashable {
    let source: MediaSource
    let id: String
    let name: String
}

struct JellyfinFolderView: View {
    @Environment(AppStore.self) private var store
    let source: MediaSource
    let folder: JellyfinFolder?
    let play: PlayAction
    @State private var entries: [JellyfinEntry] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading {
                ProgressView("Yükleniyor…").controlSize(.large)
            } else if let error {
                ContentUnavailableView {
                    Label("Yüklenemedi", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Yeniden dene") { Task { await load() } }.buttonStyle(.borderedProminent)
                }
            } else if entries.isEmpty {
                ContentUnavailableView("Bu klasör boş", systemImage: "folder")
            } else {
                let videos = entries.filter { !$0.isFolder }.compactMap(mediaItem)
                List(entries) { entry in
                    if entry.isFolder {
                        NavigationLink(value: JellyfinFolder(source: source, id: entry.id, name: entry.name)) {
                            Label(entry.name, systemImage: "folder.fill").font(.title3).frame(minHeight: 56)
                        }
                    } else if let item = mediaItem(entry) {
                        MediaRow(item: item) { play(item, videos) }
                    }
                }
            }
        }
        .navigationTitle(folder?.name ?? source.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func mediaItem(_ entry: JellyfinEntry) -> MediaItem? {
        guard let client = store.jellyfin(for: source) else { return nil }
        return MediaItem(id: "jf:\(source.id.uuidString):\(entry.id)",
                         title: entry.subtitle.isEmpty ? entry.name : "\(entry.name) · \(entry.subtitle)",
                         group: folder?.name ?? source.name,
                         logo: entry.hasImage ? client.imageURL(itemID: entry.id) : nil,
                         url: client.streamURL(itemID: entry.id), sourceID: source.id)
    }

    private func load() async {
        guard let client = store.jellyfin(for: source) else { return }
        loading = true
        error = nil
        do {
            entries = try await client.entries(parentID: folder?.id)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
