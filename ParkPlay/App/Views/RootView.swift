import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var playing: PlayRequest?

    var body: some View {
        TabView {
            SourcesView(play: play).tabItem { Label("Kaynaklar", systemImage: "tv") }
            FavoritesView(play: play).tabItem { Label("Favoriler", systemImage: "star.fill") }
            FilesView(play: play).tabItem { Label("Dosyalar", systemImage: "folder.fill") }
        }
        .fullScreenCover(item: $playing) { request in
            PlayerScreen(request: request, store: store)
        }
    }

    private func play(_ item: MediaItem, _ queue: [MediaItem]) {
        playing = PlayRequest(item: item, queue: queue)
    }
}

typealias PlayAction = (MediaItem, [MediaItem]) -> Void

/// Liste satırı: araçta rahat basılsın diye yüksek tutuldu.
struct MediaRow: View {
    @Environment(AppStore.self) private var store
    let item: MediaItem
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: action) {
                HStack(spacing: 14) {
                    AsyncImage(url: item.logo) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: item.isLive ? "tv" : "film").font(.title2).foregroundStyle(.secondary)
                    }
                    .frame(width: 56, height: 56)
                    Text(item.title).font(.title3).lineLimit(2).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                store.toggleFavorite(item)
            } label: {
                Image(systemName: store.isFavorite(item) ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundStyle(store.isFavorite(item) ? .yellow : .secondary)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isFavorite(item) ? "Favorilerden çıkar" : "Favorilere ekle")
        }
        .frame(minHeight: 64)
    }
}

struct FavoritesView: View {
    @Environment(AppStore.self) private var store
    let play: PlayAction

    var body: some View {
        NavigationStack {
            Group {
                if store.favorites.isEmpty {
                    ContentUnavailableView("Henüz favori yok", systemImage: "star",
                                           description: Text("Bir kanalın yanındaki yıldıza dokunarak buraya ekleyin."))
                } else {
                    List(store.favorites) { item in
                        MediaRow(item: item) { play(item, store.favorites) }
                    }
                }
            }
            .navigationTitle("Favoriler")
        }
    }
}

struct FilesView: View {
    let play: PlayAction
    @State private var items: [MediaItem] = []
    @State private var importing = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView("Video yok", systemImage: "folder",
                                           description: Text("İnternet olmadan izlemek için + ile video ekleyin."))
                } else {
                    List {
                        ForEach(items) { item in
                            MediaRow(item: item) { play(item, items) }
                        }
                        .onDelete { offsets in
                            offsets.map { items[$0] }.forEach(LocalLibrary.delete)
                            items = LocalLibrary.items()
                        }
                    }
                }
            }
            .navigationTitle("Dosyalar")
            .toolbar {
                Button { importing = true } label: { Label("Video ekle", systemImage: "plus") }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.movie, .video], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    let failed = LocalLibrary.importFiles(urls)
                    if !failed.isEmpty { failure = failed.joined(separator: ", ") }
                    items = LocalLibrary.items()
                }
            }
            .alert("Bazı dosyalar eklenemedi", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
            .onAppear { items = LocalLibrary.items() }
        }
    }
}
