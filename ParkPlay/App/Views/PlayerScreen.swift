import AVKit
import SwiftUI

/// Oynatılacak öğe ve içinde gezinilecek liste.
struct PlayRequest: Identifiable {
    let item: MediaItem
    let queue: [MediaItem]
    var id: String { item.id }
}

/// Araç modu oynatıcı: büyük düğmeler, az seçenek, dokununca görünen kumanda.
struct PlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var model: PlayerModel
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?

    init(request: PlayRequest, store: AppStore) {
        _model = State(initialValue: PlayerModel(item: request.item, queue: request.queue, store: store))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerLayerView(player: model.player).ignoresSafeArea()

            if model.isBuffering && model.errorText == nil {
                ProgressView().controlSize(.large).tint(.white)
            }
            if let error = model.errorText {
                VStack(spacing: 16) {
                    Label("Oynatılamadı", systemImage: "exclamationmark.triangle.fill").font(.title2.bold())
                    Text(error).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Yeniden dene") { model.retry() }.buttonStyle(.borderedProminent).controlSize(.large)
                }
                .padding(32)
            }
            if showControls { controls }
        }
        .contentShape(Rectangle())
        .onTapGesture { showControls ? hideControls() : revealControls() }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            model.start()
            revealControls()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            hideTask?.cancel()
            model.close()
        }
    }

    private var controls: some View {
        VStack {
            HStack(spacing: 16) {
                bigButton("xmark", label: "Kapat") { dismiss() }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.item.title).font(.title3.bold()).lineLimit(1)
                    if !model.item.group.isEmpty {
                        Text(model.item.group).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                bigButton(store.isFavorite(model.item) ? "star.fill" : "star", label: "Favori") {
                    store.toggleFavorite(model.item)
                    revealControls()
                }
                AirPlayButton().frame(width: 64, height: 64).background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            HStack(spacing: 28) {
                if model.hasQueue { bigButton("backward.end.fill", label: "Önceki") { model.step(-1); revealControls() } }
                if model.canSeek { bigButton("gobackward.15", label: "15 saniye geri") { model.skip(-15); revealControls() } }
                Button {
                    model.togglePlay()
                    revealControls()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 44, weight: .bold))
                        .frame(width: 104, height: 104)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(model.isPlaying ? "Duraklat" : "Oynat")
                if model.canSeek { bigButton("goforward.30", label: "30 saniye ileri") { model.skip(30); revealControls() } }
                if model.hasQueue { bigButton("forward.end.fill", label: "Sonraki") { model.step(1); revealControls() } }
            }

            Spacer()

            if model.canSeek {
                HStack(spacing: 12) {
                    Text(Self.clock(model.position)).monospacedDigit()
                    Slider(value: Binding(get: { model.position }, set: { model.seek(to: $0); revealControls() }),
                           in: 0...max(model.duration, 1))
                    Text(Self.clock(model.duration)).monospacedDigit()
                }
                .font(.callout)
            } else if model.item.isLive {
                Label("CANLI", systemImage: "dot.radiowaves.left.and.right")
                    .font(.callout.bold()).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(Color.black.opacity(0.45).ignoresSafeArea())
        .transition(.opacity)
    }

    private func bigButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .frame(width: 64, height: 64)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private func revealControls() {
        withAnimation(.easeOut(duration: 0.2)) { showControls = true }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled && model.isPlaying { hideControls() }
        }
    }

    private func hideControls() {
        withAnimation(.easeIn(duration: 0.2)) { showControls = false }
    }

    private static func clock(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class LayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {}
}

private struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .white
        view.activeTintColor = .systemGreen
        view.prioritizesVideoDevices = true
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}
