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

import AVKit
import Combine
import InfomaniakCore
import InfomaniakDI
import kDriveResources
import MediaPlayer

@MainActor public protocol VideoViewCellDelegate: AnyObject {
    func readyToPlay(_ videoPlayer: VideoPlayer)
    func errorWhilePreviewing(_ videoPlayer: VideoPlayer, error: Error)
}

public final class VideoPlayer: Pausable {
    public enum ErrorDomain: Error {
        case incompatibleFile
    }

    @LazyInjectService private var orchestrator: MediaPlayerOrchestrator

    private var player: AVPlayer?
    private var asset: AVAsset?
    private var file: File?
    public var thumbnail: UIImage? {
        didSet {
            Task { @MainActor in
                updateNowPlayingInfo()
            }
        }
    }

    public private(set) var isAudioOnly = false

    private var statusObserver: NSKeyValueObservation?
    private var playbackObserver: NSKeyValueObservation?
    private var nowPlayingMetadata: MediaMetadata?
    private var nowPlayingMetadataTask: Task<Void, Never>?
    private var nowPlayingSession: MPNowPlayingSession?

    public var onPlaybackEnded: (() -> Void)?

    public weak var previewDelegate: VideoViewCellDelegate?

    public var progressPercentage: Double {
        guard let player = player, let currentItem = player.currentItem else { return 0 }
        return player.currentTime().seconds / currentItem.duration.seconds
    }

    public var identifier: String = UUID().uuidString

    public private(set) var isReadyToPlay = false

    public var avPlayer: AVPlayer? {
        player
    }

    public init(
        frozenFile: File,
        driveFileManager: DriveFileManager,
        previewDelegate: VideoViewCellDelegate?,
        thumbnail: UIImage? = nil
    ) {
        setupPlayer(with: frozenFile, driveFileManager: driveFileManager)
        file = frozenFile
        self.previewDelegate = previewDelegate
        self.thumbnail = thumbnail
    }

    @MainActor
    private func updateNowPlayingInfo() {
        guard let player, let currentItem = player.currentItem,
              let nowPlayingInfoCenter = nowPlayingSession?.nowPlayingInfoCenter else { return }

        var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo ?? [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false

        if let nowPlayingMetadata {
            nowPlayingInfo[MPMediaItemPropertyTitle] = nowPlayingMetadata.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = nowPlayingMetadata.artist
        }

        if let artwork = nowPlayingMetadata?.artwork ?? thumbnail {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        } else {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = nil
        }

        let position = player.currentTime().seconds
        if position.isFinite {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Float(position)
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        let duration = currentItem.duration.seconds
        if duration.isFinite, duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Float(duration)
        }

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    @MainActor
    public func play() {
        guard let player else { return }
        configureNowPlaying(player: player)
        updateNowPlayingInfo()
        nowPlayingSession?.becomeActiveIfPossible(completion: nil)
        player.play()
    }

    public func stopPlayback() {
        player?.pause()
    }

    public func pause() {
        player?.pause()
        onPlaybackEnded?()
    }

    @objc private func playerItemTimeJumped(notification: Notification) {
        Task { @MainActor [weak self] in
            self?.updateNowPlayingInfo()
        }
    }

    @MainActor
    private func loadNowPlayingMetadata() {
        guard nowPlayingMetadata == nil, nowPlayingMetadataTask == nil, let asset, let fileName = file?.name else { return }
        nowPlayingMetadataTask = Task { @MainActor [weak self] in
            let commonMetadata = try? await asset.load(.commonMetadata)
            let metadata = await MediaMetadata.extractTrackMetadata(from: commonMetadata ?? [],
                                                                    playableFileName: fileName)
            guard let self else { return }
            nowPlayingMetadata = metadata
            nowPlayingMetadataTask = nil
            updateNowPlayingInfo()
        }
    }

    private func setupPlayer(with file: File, driveFileManager: DriveFileManager) {
        if !file.isLocalVersionOlderThanRemote {
            let localAsset = AVAsset(url: file.localUrl)
            asset = localAsset
            let playerItem = AVPlayerItem(asset: localAsset)
            player = AVPlayer(playerItem: playerItem)
            observePlayer(currentItem: playerItem)
        } else if let publicShareProxy = driveFileManager.publicShareProxy {
            let url = Endpoint.downloadShareLinkFile(
                driveId: publicShareProxy.driveId,
                linkUuid: publicShareProxy.shareLinkUid,
                fileId: file.id
            ).url

            let remoteAsset = AVURLAsset(url: url, options: nil)
            setupStreamingAsset(remoteAsset)

        } else if driveFileManager.apiFetcher.currentToken != nil {
            let url = Endpoint.download(file: file).url
            guard let remoteAsset = AuthenticatedMediaAsset(url: url, apiFetcher: driveFileManager.apiFetcher) else {
                return
            }
            setupStreamingAsset(remoteAsset)
        }
    }

    private func setupStreamingAsset(_ urlAsset: AVURLAsset) {
        asset = urlAsset
        Task { @MainActor in
            let playerItem = AVPlayerItem(asset: urlAsset)
            self.player = AVPlayer(playerItem: playerItem)
            self.observePlayer(currentItem: playerItem)
        }
    }

    private func observePlayer(currentItem: AVPlayerItem) {
        playbackObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self else { return }
            Task { @MainActor in
                switch player.timeControlStatus {
                case .playing:
                    self.orchestrator.newPlaybackStarted(playable: self)
                    self.configureNowPlaying(player: player)
                    await self.nowPlayingSession?.becomeActiveIfPossible()
                    self.updateNowPlayingInfo()
                case .paused:
                    self.updateNowPlayingInfo()
                default:
                    break
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemTimeJumped),
            name: .AVPlayerItemTimeJumped,
            object: currentItem
        )

        statusObserver = currentItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, let previewDelegate = self.previewDelegate else { return }
                switch item.status {
                case .readyToPlay:
                    let tracks = try? await item.asset.loadTracks(withMediaType: .video)
                    self.isAudioOnly = tracks?.isEmpty ?? true
                    self.isReadyToPlay = true
                    self.loadNowPlayingMetadata()
                    previewDelegate.readyToPlay(self)
                default:
                    previewDelegate.errorWhilePreviewing(self, error: ErrorDomain.incompatibleFile)
                }
            }
        }
    }

    @MainActor
    private func configureNowPlaying(player: AVPlayer) {
        guard nowPlayingSession == nil else { return }

        let session = MPNowPlayingSession(players: [player])
        session.automaticallyPublishesNowPlayingInfo = false
        nowPlayingSession = session
        registerRemoteCommands(session.remoteCommandCenter, for: player)
    }

    private func registerRemoteCommands(_ commands: MPRemoteCommandCenter, for player: AVPlayer) {
        commands.togglePlayPauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.addTarget { [weak player] _ in
            guard let player else { return .commandFailed }
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
            return .success
        }

        commands.playCommand.isEnabled = true
        commands.playCommand.addTarget { [weak player] _ in
            guard let player else { return .commandFailed }
            player.play()
            return .success
        }

        commands.pauseCommand.isEnabled = true
        commands.pauseCommand.addTarget { [weak player] _ in
            guard let player else { return .commandFailed }
            player.pause()
            return .success
        }

        let skipCommands: [(command: MPSkipIntervalCommand, direction: Double)] = [
            (commands.skipBackwardCommand, -1),
            (commands.skipForwardCommand, 1)
        ]
        for (command, direction) in skipCommands {
            command.isEnabled = true
            command.preferredIntervals = [15]
            command.addTarget { [weak player] event in
                guard let player,
                      let duration = player.currentItem?.duration.seconds,
                      let event = event as? MPSkipIntervalCommandEvent else {
                    return .commandFailed
                }

                let currentTime = player.currentTime().seconds
                guard currentTime.isFinite, duration.isFinite, duration > 0 else { return .commandFailed }

                let targetTime = min(max(currentTime + direction * event.interval, 0), duration)
                player.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
                return .success
            }
        }

        commands.changePlaybackPositionCommand.isEnabled = true
        commands.changePlaybackPositionCommand.addTarget { [weak player] event in
            guard let player, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            player.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 600))
            return .success
        }
    }
}
