/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import Combine
import InfomaniakCore
import InfomaniakDI
import kDriveResources
import MediaPlayer

/// Track one file been played
public final class SingleTrackPlayer: Pausable {
    @LazyInjectService private var orchestrator: MediaPlayerOrchestrator

    let registeredCommands: [NowPlayableCommand] = [
        .togglePausePlay,
        .play,
        .pause,
        .skipBackward,
        .skipForward,
        .changePlaybackPosition,
        .changePlaybackRate
    ]

    private let driveFileManager: DriveFileManager
    private var currentTrackMetadata: MediaMetadata?

    // MARK: Player Observation

    private var interruptionObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var rateObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var currentItemStatusObserver: NSKeyValueObservation?
    private var isInterrupted = false

    // MARK: Data flow

    public let onPlaybackError = PassthroughSubject<DomainError, Never>()
    public let onPlayerStateChange = PassthroughSubject<SingleTrackPlayer.State, Never>()
    public let onElapsedTimeChange = PassthroughSubject<String, Never>()
    public let onRemainingTimeChange = PassthroughSubject<String, Never>()
    public let onPositionChange = PassthroughSubject<Float, Never>()
    public let onPositionMaximumChange = PassthroughSubject<Float, Never>()
    public let onCurrentTrackMetadata = PassthroughSubject<MediaMetadata, Never>()

    var player: AVPlayer?

    var playerState: SingleTrackPlayer.State = .stopped {
        didSet {
            onPlayerStateChange.send(playerState)
        }
    }

    public var identifier: String = UUID().uuidString

    public var progressPercentage: Double {
        player?.progressPercentage ?? 0.0
    }

    public enum State {
        case stopped
        case playing
        case paused
    }

    public enum DomainError: Error {
        /// Issue loading preview, missing auth token
        case previewLoadErrorNoToken
    }

    public init(driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
    }

    deinit {
        reset()
    }

    // MARK: - Load

    /// Load internal structures to play a single track
    ///
    /// Async as may take up some time
    public func setup(with playableFile: File) async { // TODO: use abstract type
        if !playableFile.isLocalVersionOlderThanRemote {
            let asset = AVAsset(url: playableFile.localUrl)
            player = AVPlayer(url: playableFile.localUrl)
            setUpObservers()
            Task {
                await setMetaData(from: asset.commonMetadata, playableFileName: playableFile.name)
            }
        } else if let token = driveFileManager.apiFetcher.currentToken {
            driveFileManager.apiFetcher.performAuthenticatedRequest(token: token) { token, _ in
                guard let token else { return }
                Task { @MainActor in
                    let url = Endpoint.download(file: playableFile).url
                    let headers = ["Authorization": "Bearer \(token.accessToken)"]
                    let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                    self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                    await self.setMetaData(from: asset.commonMetadata, playableFileName: playableFile.name)
                    self.setUpObservers()

                    self.currentItemStatusObserver = self.player?.observe(\.currentItem?.status) { player, _ in
                        guard let error = player.currentItem?.error,
                              let avError = error as? AVError,
                              avError.code == .fileFormatNotRecognized else { return }
                    }
                }
            }
        } else {
            onPlaybackError.send(.previewLoadErrorNoToken)
        }
    }

    public func reset() {
        removeAllObservers()
        player?.pause()
        player = nil
        playerState = .stopped
    }

    private func setMetaData(from metadata: [AVMetadataItem], playableFileName: String?) async {
        let mediaMetadata = await MediaMetadata.extractTrackMetadata(from: metadata, playableFileName: playableFileName)
        currentTrackMetadata = mediaMetadata
        onCurrentTrackMetadata.send(mediaMetadata)
    }

    // MARK: - MediaPlayer

    private func setNowPlayingMetadata() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false

        guard let currentTrackMetadata else { return }
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrackMetadata.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = currentTrackMetadata.artist

        if let artwork = currentTrackMetadata.artwork {
            let artworkItem = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artworkItem
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func setPlaybackInfo(time: CMTime) {
        let elapsedTime = time.formattedText
        onElapsedTimeChange.send(elapsedTime)
        let positionSlider = Float(time.seconds)
        onPositionChange.send(positionSlider)

        if let duration = player?.currentItem?.duration {
            let remainingTime = "−\((duration - time).formattedText)"
            onRemainingTimeChange.send(remainingTime)
        }
    }

    private func setNowPlayingPlaybackInfo() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        if let position = player?.currentItem?.currentTime() {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Float(position.seconds)
            let remainingTime = position.formattedText
            onRemainingTimeChange.send(remainingTime)
            let positionSlider = Float(position.seconds)
            onPositionChange.send(positionSlider)
        }

        if let rate = player?.rate {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        if let player = player, let duration = player.currentItem?.duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Float(duration.seconds)
            let elapsedTime = player.currentItem?.currentTime() ?? .zero

            let remainingTime = "−\((duration - elapsedTime).formattedText)"
            onRemainingTimeChange.send(remainingTime)
            let maximumPosition = duration.seconds.isFinite ? Float(duration.seconds) : 1
            onPositionMaximumChange.send(maximumPosition)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Interruptions

    private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptionTypeUInt = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeUInt) else { return }

        switch interruptionType {
        case .began:
            isInterrupted = true
        case .ended:
            isInterrupted = false

            var shouldResume = false
            if let optionsUInt = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsUInt).contains(.shouldResume) {
                shouldResume = true
            }

            if playerState == .playing {
                if shouldResume {
                    play()
                } else {
                    playerState = .paused
                }
            }
        @unknown default:
            break
        }
    }

    // MARK: - Observation

    private func setUpObservers() {
        defer {
            setUpRemoteControlEvents()
        }

        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                                                      object: AVAudioSession.sharedInstance(),
                                                                      queue: .main) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification: notification)
        }
        startPlaybackObservationIfNeeded()

        guard let player else {
            return
        }

        rateObserver = player.observe(\.rate, options: .initial) { [weak self] _, _ in
            self?.setNowPlayingPlaybackInfo()
        }
        statusObserver = player.observe(\.currentItem?.status, options: .initial) { [weak self] _, _ in
            self?.setNowPlayingPlaybackInfo()
        }

        if let currentItem = player.currentItem {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }
    }

    private func removeAllObservers() {
        if let interruptionObserver = interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }

        stopPlaybackObservation()

        rateObserver?.invalidate()
        rateObserver = nil

        statusObserver?.invalidate()
        statusObserver = nil

        removeAllRemoteControlEvents()
    }

    public func startPlaybackObservationIfNeeded() {
        guard timeObserver == nil else {
            return
        }

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 10),
            queue: DispatchQueue.main
        ) { [weak self] time in
            self?.setPlaybackInfo(time: time)
        }
    }

    public func stopPlaybackObservation() {
        guard let timeObserver else {
            return
        }

        player?.removeTimeObserver(timeObserver)
        self.timeObserver = nil
    }

    @objc private func playerDidFinishPlaying() {
        pause()
        seek(to: 0)
    }

    // MARK: - Commands

    public func play() {
        if playerState == .stopped {
            setNowPlayingMetadata()
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                SentryDebug.capture(error: error)
            }
        }

        guard let player else {
            return
        }

        playerState = .playing
        isInterrupted = false
        player.play()

        orchestrator.newPlaybackStarted(playable: self)
    }

    public func pause() {
        playerState = .paused
        isInterrupted = false
        player?.pause()
    }

    public func togglePlayPause() {
        switch playerState {
        case .playing:
            pause()
            MatomoUtils.track(eventWithCategory: .mediaPlayer, name: "pause")
        case .stopped, .paused:
            play()
            MatomoUtils.trackMediaPlayer(playMedia: .audio)
        }
    }

    public func seek(to time: CMTime) {
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { isFinished in
            guard isFinished else { return }
            self.startPlaybackObservationIfNeeded()
            self.setNowPlayingPlaybackInfo()
        }
    }

    public func seek(to position: TimeInterval) {
        seek(to: CMTime(seconds: position, preferredTimescale: 1))
    }

    public func skipForward(by interval: TimeInterval) {
        guard let player else { return }
        seek(to: player.currentTime() + CMTime(seconds: interval, preferredTimescale: 1))
    }

    public func skipBackward(by interval: TimeInterval) {
        guard let player else { return }
        seek(to: player.currentTime() - CMTime(seconds: interval, preferredTimescale: 1))
    }

    public func setPlaybackRate(_ rate: Float) {
        if case .stopped = playerState {
            return
        }

        player?.rate = rate
    }
}

public extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }

    var progressPercentage: Double {
        guard let currentItem else { return 0 }
        return (currentItem.currentTime().seconds * 100) / currentItem.duration.seconds
    }
}

public extension CMTime {
    static let unknownTimeText = "--:--"
    static let zeroTimeText = "0:00"

    var formattedText: String {
        let totalSeconds = seconds
        guard totalSeconds.isFinite else { return Self.unknownTimeText }
        let hours = Int(totalSeconds.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%i:%02i", minutes, seconds)
        }
    }
}
