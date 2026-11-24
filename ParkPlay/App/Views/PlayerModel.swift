import AVFoundation
import Combine
import MediaPlayer
import Observation

@MainActor
@Observable
final class PlayerModel {
    let player = AVPlayer()
    private(set) var item: MediaItem
    private(set) var isPlaying = false
    private(set) var isBuffering = true
    private(set) var position: Double = 0
    private(set) var duration: Double = 0
    private(set) var errorText: String?

    @ObservationIgnored private let queue: [MediaItem]
    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var subscriptions = Set<AnyCancellable>()
    @ObservationIgnored private var itemSubscription: AnyCancellable?
    @ObservationIgnored private var lastSave: Double = 0
    @ObservationIgnored private var started = false

    var hasQueue: Bool { queue.count > 1 }
    var canSeek: Bool { !item.isLive && duration > 0 }

    init(item: MediaItem, queue: [MediaItem], store: AppStore) {
        self.item = item
        self.queue = queue
        self.store = store
    }

    /// Ekran göründüğünde bir kez çağrılır. `init` yan etkisizdir, çünkü SwiftUI
    /// görünümü yeniden kurarken kullanılmayacak kopyalar oluşturabilir.
    func start() {
        guard !started else { return }
        started = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        // AirPlay destekleyen araç ekranına / alıcıya görüntüyü doğrudan gönder.
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = status != .paused
                self?.isBuffering = status == .waitingToPlayAtSpecifiedRate
            }
            .store(in: &subscriptions)

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 2), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time.seconds) }
        }
        setupRemoteCommands()
        load(item)
    }

    private func load(_ newItem: MediaItem) {
        saveProgress()
        item = newItem
        errorText = nil
        position = 0
        duration = 0
        isBuffering = true

        let playerItem = AVPlayerItem(url: store.playableURL(for: newItem))
        itemSubscription = playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                if status == .failed {
                    self.isBuffering = false
                    self.errorText = playerItem.error?.localizedDescription ?? "Bu yayın açılamadı."
                } else if status == .readyToPlay {
                    let seconds = playerItem.duration.seconds
                    self.duration = seconds.isFinite ? seconds : 0
                }
            }
        player.replaceCurrentItem(with: playerItem)

        let resume = store.resumePosition(for: newItem)
        if resume > 0 { player.seek(to: CMTime(seconds: resume, preferredTimescale: 600)) }
        player.play()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: newItem.title,
            MPMediaItemPropertyAlbumTitle: newItem.group,
            MPNowPlayingInfoPropertyIsLiveStream: newItem.isLive,
        ]
    }

    private func tick(_ seconds: Double) {
        guard seconds.isFinite else { return }
        position = seconds
        if abs(seconds - lastSave) >= 10 { saveProgress() }
    }

    private func saveProgress() {
        lastSave = position
        store.setResume(position, duration: duration, for: item)
    }

    // MARK: Kumanda

    func togglePlay() { isPlaying ? player.pause() : player.play() }

    func retry() { load(item) }

    func skip(_ delta: Double) {
        guard canSeek else { return }
        seek(to: min(max(position + delta, 0), duration))
    }

    func seek(to seconds: Double) {
        position = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    /// Listede bir sonraki / önceki kanala geçer (uçlarda başa sarar).
    func step(_ offset: Int) {
        guard hasQueue, let index = queue.firstIndex(where: { $0.id == item.id }) else { return }
        load(queue[(index + offset + queue.count) % queue.count])
    }

    func close() {
        saveProgress()
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        itemSubscription = nil
        subscriptions.removeAll()
        let center = MPRemoteCommandCenter.shared()
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                        center.nextTrackCommand, center.previousTrackCommand] {
            command.removeTarget(nil)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Direksiyon tuşları, kilit ekranı ve CarPlay "Şimdi Çalıyor" ekranı bu komutları kullanır.
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.player.play(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.player.pause(); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlay(); return .success }
        center.nextTrackCommand.isEnabled = hasQueue
        center.previousTrackCommand.isEnabled = hasQueue
        center.nextTrackCommand.addTarget { [weak self] _ in self?.step(1); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.step(-1); return .success }
    }
}
