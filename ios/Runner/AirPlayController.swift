import AVFoundation
import MediaPlayer

final class AirPlayController {
    private var eventSink: FlutterEventSink?
    private(set) var isActive = false
    private var playbackState = "idle"
    private var latestPositionTicks: Int64 = 0

    private var avPlayer: AVPlayer?
    private var avPlayerTimeObserver: Any?
    private var pendingUrl: String?
    private var pendingTitle: String = ""
    private var pendingPositionSeconds: Double = 0

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        setupRemoteCommands()
        refreshRouteStatus()
    }

    deinit {
        stopNativePlayer()
        NotificationCenter.default.removeObserver(self)
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.removeTarget(self)
        cc.pauseCommand.removeTarget(self)
        cc.changePlaybackPositionCommand.removeTarget(self)
    }

    // MARK: - Native AirPlay playback (detail-screen cast)

    /// Queue content to play as soon as AirPlay becomes the active route.
    /// If AirPlay is already active the content starts immediately.
    func preparePendingContent(urlString: String, title: String, positionSeconds: Double) {
        pendingUrl = urlString
        pendingTitle = title
        pendingPositionSeconds = positionSeconds
        if isActive {
            DispatchQueue.main.async { self.startPendingContent() }
        }
    }

    private func startPendingContent() {
        guard let urlString = pendingUrl, let url = URL(string: urlString) else { return }
        pendingUrl = nil

        stopNativePlayer()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        avPlayer = player

        if pendingPositionSeconds > 0 {
            player.seek(to: CMTime(seconds: pendingPositionSeconds, preferredTimescale: 600))
        }

        avPlayerTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, self.avPlayer != nil else { return }
            self.latestPositionTicks = Int64(time.seconds * 10_000_000)
            self.emitCurrentPlaybackEvent(force: false)
        }

        player.play()
        playbackState = "playing"

        let nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: pendingTitle,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: pendingPositionSeconds,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        emitCurrentPlaybackEvent(force: true)
    }

    private func stopNativePlayer() {
        if let observer = avPlayerTimeObserver {
            avPlayer?.removeTimeObserver(observer)
            avPlayerTimeObserver = nil
        }
        avPlayer?.pause()
        avPlayer = nil
    }

    func setEventSink(_ sink: FlutterEventSink?) {
        eventSink = sink
        guard sink != nil else { return }
        emitEvent(state: isActive ? "connected" : "disconnected")
        emitCurrentPlaybackEvent(force: true)
    }

    // MARK: - Transport control (called from Flutter method channel)

    func pause() {
        avPlayer?.pause()
        updateNowPlayingRate(0.0)
        playbackState = "paused"
        emitCurrentPlaybackEvent(force: true)
    }

    func play() {
        avPlayer?.play()
        updateNowPlayingRate(1.0)
        playbackState = "playing"
        emitCurrentPlaybackEvent(force: true)
    }

    func seek(positionTicks: Int64) {
        latestPositionTicks = max(0, positionTicks)
        if let player = avPlayer {
            let seconds = Double(max(0, positionTicks)) / 10_000_000.0
            player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        }
        updateNowPlayingElapsed(positionTicks)
        emitCurrentPlaybackEvent(force: true)
    }

    func updatePlaybackState(isPlaying: Bool, isBuffering: Bool, positionTicks: Int64) {
        if avPlayer != nil {
            stopNativePlayer()
            pendingUrl = nil
        }
        latestPositionTicks = max(0, positionTicks)
        if isBuffering {
            playbackState = "buffering"
        } else if isPlaying {
            playbackState = "playing"
        } else {
            playbackState = "paused"
        }

        updateNowPlayingElapsed(latestPositionTicks)
        updateNowPlayingRate(isPlaying && !isBuffering ? 1.0 : 0.0)
        emitCurrentPlaybackEvent(force: false)
    }

    func stop() {
        stopNativePlayer()
        pendingUrl = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if isActive {
            isActive = false
            emitEvent(state: "disconnected")
        }
        playbackState = "idle"
        latestPositionTicks = 0
        emitCurrentPlaybackEvent(force: true)
    }

    // MARK: - Private

    private func detectAirPlay() -> Bool {
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            $0.portType == .airPlay
        }
    }

    private func refreshRouteStatus() {
        let nextActive = detectAirPlay()
        let wasActive = isActive
        isActive = nextActive

        guard wasActive != isActive else {
            emitCurrentPlaybackEvent(force: false)
            return
        }
        DispatchQueue.main.async {
            self.emitEvent(state: self.isActive ? "connected" : "disconnected")
            self.emitCurrentPlaybackEvent(force: true)
            if self.isActive && self.pendingUrl != nil {
                self.startPendingContent()
            }
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        refreshRouteStatus()
    }

    private func setupRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()

        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            self?.playbackState = "playing"
            self?.emitEvent(state: "command", command: "play")
            return .success
        }

        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            self?.playbackState = "paused"
            self?.emitEvent(state: "command", command: "pause")
            return .success
        }

        cc.changePlaybackPositionCommand.isEnabled = true
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let ticks = Int64(posEvent.positionTime * 10_000_000)
            self?.emitEvent(state: "command", command: "seek", positionTicks: ticks)
            return .success
        }
    }

    private func emitCurrentPlaybackEvent(force: Bool) {
        guard isActive || force else { return }
        emitEvent(state: playbackState, positionTicks: latestPositionTicks)
    }

    private func updateNowPlayingRate(_ rate: Double) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsed(_ positionTicks: Int64) {
        let seconds = Double(max(0, positionTicks)) / 10_000_000.0
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func emitEvent(state: String, command: String? = nil, positionTicks: Int64? = nil) {
        var event: [String: Any] = [
            "kind": "airPlay",
            "state": state,
        ]
        if let command { event["command"] = command }
        if let positionTicks, positionTicks > 0 { event["positionTicks"] = positionTicks }
        eventSink?(event)
    }
}
