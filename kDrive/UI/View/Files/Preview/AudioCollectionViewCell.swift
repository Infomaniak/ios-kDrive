/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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

import AVKit
import Combine
import InfomaniakCore
import kDriveCore
import kDriveResources
import MediaPlayer
import UIKit

/// Track one file been played
final class SingleTrackPlayer {
    private let registeredCommands: [NowPlayableCommand] = [
        .togglePausePlay,
        .play,
        .pause,
        .skipBackward,
        .skipForward,
        .changePlaybackPosition,
        .changePlaybackRate
    ]

    private let driveFileManager: DriveFileManager

    private var playerState: SingleTrackPlayer.State = .stopped {
        didSet {
            onPlayerStateChange.send(playerState)
        }
    }

    // data
    private var playableFileName: String?

    // observation
    private var interruptionObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var rateObserver: NSKeyValueObservation?
    private var statusObserver: NSObjectProtocol?
    private var isInterrupted = false

    // "delegation"
    public let onPlaybackError = PassthroughSubject<DomainError, Never>()
    public let onPlayerStateChange = PassthroughSubject<SingleTrackPlayer.State, Never>()
    public let onElapsedTimeChange = PassthroughSubject<String, Never>()
    public let onRemainingTimeChange = PassthroughSubject<String, Never>()
    public let onPositionChange = PassthroughSubject<Float, Never>()
    public let onPositionMaximumChange = PassthroughSubject<Float, Never>()

    // Player
    var player: AVPlayer?

    var progressPercentage: Double {
        player?.progressPercentage ?? 0.0
    }

    public enum State {
        case stopped
        case playing
        case paused
    }

    enum DomainError: Error {
        // Issue loading preview, missing auth token
        case previewLoadErrorNoToken
    }

    init(driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
    }

    deinit {
        reset()
    }

    // MARK: Load

    /// Load internal sturctures to play a single track
    ///
    /// Async as may take up some time
    public func setup(with playableFile: File) async { // TODO: use abstract type
        playableFileName = playableFile.name

        if !playableFile.isLocalVersionOlderThanRemote {
            player = AVPlayer(url: playableFile.localUrl)
            setUpObservers()
        } else if let token = driveFileManager.apiFetcher.currentToken {
            driveFileManager.apiFetcher.performAuthenticatedRequest(token: token) { token, _ in
                if let token {
                    let url = Endpoint.download(file: playableFile).url
                    let headers = ["Authorization": "Bearer \(token.accessToken)"]
                    let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                    Task {
                        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                        self.setUpObservers()
                    }
                } else {
                    self.onPlaybackError.send(.previewLoadErrorNoToken)
                }
            }
        } else {
            onPlaybackError.send(.previewLoadErrorNoToken)
        }
    }

    public func reset() {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        rateObserver = nil
        statusObserver = nil

        player?.pause()
        player = nil
        playerState = .stopped
    }

    // MARK: MediaPlayer

    private func setNowPlayingMetadata() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
        nowPlayingInfo[MPMediaItemPropertyTitle] = playableFileName ?? ""

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

        if let duration = player?.currentItem?.duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Float(duration.seconds)
            let elapsedTime = player?.currentItem?.currentTime() ?? .zero

            let remainingTime = "−\((duration - elapsedTime).formattedText)"
            onRemainingTimeChange.send(remainingTime)
            let maximumPosition = duration.seconds.isFinite ? Float(duration.seconds) : 1
            onPositionMaximumChange.send(maximumPosition)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: Interruptions

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

    // MARK: Observation

    func setUpObservers() {
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                                                      object: AVAudioSession.sharedInstance(),
                                                                      queue: .main) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification: notification)
        }
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 10),
            queue: DispatchQueue.main
        ) { [weak self] time in
            self?.setPlaybackInfo(time: time)
        }
        rateObserver = player?.observe(\.rate, options: .initial) { [weak self] _, _ in
            self?.setNowPlayingPlaybackInfo()
        }
        statusObserver = player?.observe(\.currentItem?.status, options: .initial) { [weak self] _, _ in
            self?.setNowPlayingPlaybackInfo()
        }

        if let currentItem = player?.currentItem {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }
        setUpRemoteControlEvents()
    }

    private func setUpRemoteControlEvents() {
        for command in registeredCommands {
            command.removeHandler()

            command.addHandler { [weak self] command, event in
                guard let self else {
                    return .commandFailed
                }
                switch command {
                case .togglePausePlay:
                    togglePlayPause()
                case .play:
                    play()
                case .pause:
                    pause()
                case .skipBackward:
                    guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
                    skipBackward(by: event.interval)
                case .skipForward:
                    guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
                    skipForward(by: event.interval)
                case .changePlaybackPosition:
                    guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
                    seek(to: event.positionTime)
                case .changePlaybackRate:
                    guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
                    setPlaybackRate(event.playbackRate)
                default:
                    return .commandFailed
                }
                return .success
            }
        }
    }

    @objc private func playerDidFinishPlaying() {
        pause()
        seek(to: 0)
    }

    // MARK: Commands

    public func play() {
        if playerState == .stopped {
            setNowPlayingMetadata()
        }
        playerState = .playing
        isInterrupted = false
        player?.play()
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
        if case .stopped = playerState { return }
        player?.rate = rate
    }
}

final class AudioCollectionViewCell: PreviewCollectionViewCell {
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var elapsedTimeLabel: UILabel!
    @IBOutlet var remainingTimeLabel: UILabel!
    @IBOutlet var positionSlider: UISlider!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var landscapePlayButton: UIButton!
    @IBOutlet var iconHeightConstraint: NSLayoutConstraint!

    var driveFileManager: DriveFileManager!

    lazy var singleTrackPlayer = SingleTrackPlayer(driveFileManager: driveFileManager)

    private var cancellables = Set<AnyCancellable>()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Change slider thumb
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        let circleImage = renderer.image { ctx in
            KDriveResourcesAsset.infomaniakColor.color.setFill()
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fill)
        }
        elapsedTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        remainingTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        positionSlider.setThumbImage(circleImage, for: .normal)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rotated),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        setControls(enabled: false)
    }

    @MainActor func setControls(enabled: Bool) {
        elapsedTimeLabel.text = CMTime.zeroTimeText
        remainingTimeLabel.text = CMTime.unknownTimeText
        positionSlider.value = 0.0
        playButton.isEnabled = enabled
        landscapePlayButton.isEnabled = enabled
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setControls(enabled: false)
        singleTrackPlayer.reset()
    }

    override func configureWith(file: File) {
        assert(file.isFrozen, "file should be frozen for safe async work in the player")

        Task {
            setUpPlayButtons()
            await singleTrackPlayer.setup(with: file)
            setControls(enabled: true)
            setupObservation()
        }
    }

    /// Setup data flow
    @MainActor func setupObservation() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        singleTrackPlayer
            .onPlayerStateChange
            .receive(on: DispatchQueue.main)
            .sink { newState in
                self.updateUI(state: newState)
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onPlaybackError
            .receive(on: DispatchQueue.main)
            .sink { _ in
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.previewLoadError)
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onElapsedTimeChange
            .receive(on: DispatchQueue.main)
            .sink { elapsedTime in
                self.elapsedTimeLabel.text = elapsedTime
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onRemainingTimeChange
            .receive(on: DispatchQueue.main)
            .sink { remainingTime in
                self.remainingTimeLabel.text = remainingTime
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onPositionChange
            .receive(on: DispatchQueue.main)
            .sink { newPosition in
                guard !self.positionSlider.isTracking else { return }
                self.positionSlider.setValue(newPosition, animated: true)
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onPositionMaximumChange
            .receive(on: DispatchQueue.main)
            .sink { sliderMaximum in
                self.positionSlider.maximumValue = sliderMaximum
            }
            .store(in: &cancellables)
    }

    @MainActor func setUpPlayButtons() {
        let isPortrait = (window?.windowScene?.interfaceOrientation.isPortrait ?? true)
        playButton.isHidden = !isPortrait
        landscapePlayButton.isHidden = isPortrait
        iconHeightConstraint.constant = isPortrait ? 254 : 120
    }

    @objc func rotated() {
        setUpPlayButtons()
    }

    @IBAction func playButtonPressed(_ sender: UIButton) {
        togglePlayPause()
    }

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        seek(to: TimeInterval(sender.value))
    }

    override func didEndDisplaying() {
        MatomoUtils.trackMediaPlayer(leaveAt: singleTrackPlayer.progressPercentage)
        singleTrackPlayer.reset()
    }

    private func updateUI(state: SingleTrackPlayer.State) {
        if state == .playing {
            playButton?.setImage(KDriveResourcesAsset.pause.image, for: .normal)
            landscapePlayButton?.setImage(KDriveResourcesAsset.pause.image, for: .normal)
        } else {
            playButton?.setImage(KDriveResourcesAsset.play.image, for: .normal)
            landscapePlayButton?.setImage(KDriveResourcesAsset.play.image, for: .normal)
        }
    }

    func play() {
        singleTrackPlayer.play()
    }

    func pause() {
        singleTrackPlayer.pause()
    }

    func togglePlayPause() {
        singleTrackPlayer.togglePlayPause()
    }

    func seek(to time: CMTime) {
        singleTrackPlayer.seek(to: time)
    }

    func seek(to position: TimeInterval) {
        singleTrackPlayer.seek(to: position)
    }

    func skipForward(by interval: TimeInterval) {
        singleTrackPlayer.skipForward(by: interval)
    }

    func skipBackward(by interval: TimeInterval) {
        singleTrackPlayer.skipBackward(by: interval)
    }

    func setPlaybackRate(_ rate: Float) {
        singleTrackPlayer.setPlaybackRate(rate)
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }

    var progressPercentage: Double {
        guard let currentItem else { return 0 }
        return (currentItem.currentTime().seconds * 100) / currentItem.duration.seconds
    }
}

extension CMTime {
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
