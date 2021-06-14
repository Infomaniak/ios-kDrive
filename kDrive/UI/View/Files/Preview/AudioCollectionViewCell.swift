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

import UIKit
import AVKit
import MediaPlayer
import kDriveCore

class AudioCollectionViewCell: PreviewCollectionViewCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var elapsedTimeLabel: UILabel!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    @IBOutlet weak var positionSlider: UISlider!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var landscapePlayButton: UIButton!
    @IBOutlet weak var iconHeightConstraint: NSLayoutConstraint!

    private var file: File!
    private var player: AVPlayer?
    private var playerState: PlayerState = .stopped {
        didSet { updateUI() }
    }
    private var isInterrupted = false {
        didSet { updateUI() }
    }

    private var interruptionObserver: NSObjectProtocol!
    private var timeObserver: Any!
    private var rateObserver: NSKeyValueObservation!
    private var statusObserver: NSObjectProtocol!

    private let registeredCommands: [NowPlayableCommand] = [.togglePausePlay, .play, .pause, .skipBackward, .skipForward, .changePlaybackPosition, .changePlaybackRate]

    enum PlayerState {
        case stopped
        case playing
        case paused
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Change slider thumb
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        let circleImage = renderer.image { ctx in
            KDriveAsset.infomaniakColor.color.setFill()
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fill)
        }
        elapsedTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        remainingTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        positionSlider.setThumbImage(circleImage, for: .normal)

        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        optOut()
    }

    override func configureWith(file: File) {
        setUpPlayButtons()
        self.file = file
        let url: AVURLAsset
        if !file.isLocalVersionOlderThanRemote() {
            url = AVURLAsset(url: file.localUrl)
        } else {
            let headers = ["Authorization": "Bearer \(AccountManager.instance.currentAccount.token.accessToken)"]
            url = AVURLAsset(url: URL(string: ApiRoutes.downloadFile(file: file))!, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        }
        // Set up player
        player = AVPlayer(playerItem: AVPlayerItem(asset: url))
        setUpObservers()
    }

    func setUpPlayButtons() {
        playButton.isHidden = UIApplication.shared.statusBarOrientation.isLandscape
        landscapePlayButton.isHidden = UIApplication.shared.statusBarOrientation.isPortrait
        iconHeightConstraint.constant = UIApplication.shared.statusBarOrientation.isPortrait ? 254 : 120
    }

    func setUpObservers() {
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification: notification)
        }
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 10), queue: DispatchQueue.main) { [weak self] time in
            guard let strongSelf = self else { return }
            strongSelf.elapsedTimeLabel.text = time.formattedText
            if let duration = strongSelf.player?.currentItem?.duration {
                strongSelf.remainingTimeLabel.text = "−\((duration - time).formattedText)"
            }
            if !strongSelf.positionSlider.isTracking {
                strongSelf.positionSlider.setValue(Float(time.seconds), animated: true)
            }
        }
        rateObserver = player?.observe(\.rate, options: .initial) { [weak self] _, _ in
            self?.setNowPlayingPlaybackInfo()
        }
        statusObserver = player?.observe(\.currentItem?.status, options: .initial) { [weak self] _, _ in
            self?.setNowPlayingPlaybackInfo()
        }
        setUpRemoteControlEvents()
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
        optOut()
    }

    private func setUpRemoteControlEvents() {
        for command in registeredCommands {
            command.removeHandler()

            command.addHandler { [unowned self] command, event in
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

    private func setNowPlayingMetadata() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
        nowPlayingInfo[MPMediaItemPropertyTitle] = file.name

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func setNowPlayingPlaybackInfo() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        if let position = player?.currentItem?.currentTime() {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Float(position.seconds)
            elapsedTimeLabel.text = position.formattedText
            positionSlider.setValue(Float(position.seconds), animated: true)
        }
        if let rate = player?.rate {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        if let duration = player?.currentItem?.duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Float(duration.seconds)
            let elapsedTime = player?.currentItem?.currentTime() ?? .zero
            remainingTimeLabel.text = "−\((duration - elapsedTime).formattedText)"
            positionSlider.maximumValue = duration.seconds.isFinite ? Float(duration.seconds) : 1
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

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

    private func updateUI() {
        if playerState == .playing && !isInterrupted {
            playButton?.setImage(KDriveAsset.pause.image, for: .normal)
            landscapePlayButton?.setImage(KDriveAsset.pause.image, for: .normal)
        } else {
            playButton?.setImage(KDriveAsset.play.image, for: .normal)
            landscapePlayButton?.setImage(KDriveAsset.play.image, for: .normal)
        }
    }

    private func optOut() {
        if let interruptionObserver = interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        rateObserver = nil
        statusObserver = nil

        player?.pause()
        playerState = .stopped
    }

    func play() {
        if playerState == .stopped {
            setNowPlayingMetadata()
        }
        playerState = .playing
        isInterrupted = false
        player?.play()
    }

    func pause() {
        playerState = .paused
        isInterrupted = false
        player?.pause()
    }

    func togglePlayPause() {
        switch playerState {
        case .playing:
            pause()
        case .stopped, .paused:
            play()
        }
    }

    func seek(to time: CMTime) {
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { isFinished in
            if isFinished {
                self.setNowPlayingPlaybackInfo()
            }
        }
    }

    func seek(to position: TimeInterval) {
        seek(to: CMTime(seconds: position, preferredTimescale: 1))
    }

    func skipForward(by interval: TimeInterval) {
        guard let player = player else { return }
        seek(to: player.currentTime() + CMTime(seconds: interval, preferredTimescale: 1))
    }

    func skipBackward(by interval: TimeInterval) {
        guard let player = player else { return }
        seek(to: player.currentTime() - CMTime(seconds: interval, preferredTimescale: 1))
    }

    func setPlaybackRate(_ rate: Float) {
        if case .stopped = playerState { return }

        player?.rate = rate
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}

extension CMTime {
    var formattedText: String {
        let totalSeconds = seconds
        guard totalSeconds.isFinite else { return "--:--" }
        let hours = Int(totalSeconds.truncatingRemainder(dividingBy: 86_400) / 3_600)
        let minutes = Int(totalSeconds.truncatingRemainder(dividingBy: 3_600) / 60)
        let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%i:%02i", minutes, seconds)
        }
    }
}
