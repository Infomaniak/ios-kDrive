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
    public private(set) var isAudioOnly = false

    private var statusObserver: NSKeyValueObservation?
    private var playbackObserver: NSKeyValueObservation?
    private var nowPlayingMetadata: MediaMetadata?
    private var nowPlayingMetadataTask: Task<Void, Never>?

    public var onPlaybackEnded: (() -> Void)?

    public weak var previewDelegate: VideoViewCellDelegate?

    public var progressPercentage: Double {
        guard let player = player, let currentItem = player.currentItem else { return 0 }
        return player.currentTime().seconds / currentItem.duration.seconds
    }

    public var identifier: String = UUID().uuidString

    public private(set) var isReadyToPlay = false

    public lazy var playerViewController: AVPlayerViewController = {
        let playerViewController = AVPlayerViewController()
        playerViewController.player = self.player
        return playerViewController
    }()

    public init(frozenFile: File, driveFileManager: DriveFileManager, previewDelegate: VideoViewCellDelegate?) {
        setupPlayer(with: frozenFile, driveFileManager: driveFileManager)
        file = frozenFile
        self.previewDelegate = previewDelegate
    }

    public func setNowPlayingMetadata(metadata: MediaMetadata) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false

        nowPlayingInfo[MPMediaItemPropertyTitle] = metadata.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = metadata.artist
        if let artwork = metadata.artwork {
            let artworkItem = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artworkItem
        }

        if let player,
           let currentItem = player.currentItem {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = CMTimeGetSeconds(currentItem.duration)
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(player.currentTime())
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    public func stopPlayback() {
        player?.pause()
    }

    public func pause() {
        player?.pause()
        onPlaybackEnded?()
    }

    @objc func playerStateChanged(notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self, orchestrator.isCurrentPlayback(self) else { return }
            publishNowPlayingMetadata()
        }
    }

    @MainActor
    private func publishNowPlayingMetadata() {
        if let nowPlayingMetadata {
            setNowPlayingMetadata(metadata: nowPlayingMetadata)
            return
        }

        guard nowPlayingMetadataTask == nil, let asset, let fileName = file?.name else { return }
        nowPlayingMetadataTask = Task { @MainActor [weak self] in
            let commonMetadata = try? await asset.load(.commonMetadata)
            let metadata = await MediaMetadata.extractTrackMetadata(from: commonMetadata ?? [],
                                                                    playableFileName: fileName)
            guard let self else { return }
            nowPlayingMetadata = metadata
            nowPlayingMetadataTask = nil
            guard orchestrator.isCurrentPlayback(self) else { return }
            setNowPlayingMetadata(metadata: metadata)
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
            guard player.timeControlStatus == .playing, let self else { return }
            Task { @MainActor in
                self.orchestrator.newPlaybackStarted(playable: self)
                self.publishNowPlayingMetadata()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerStateChanged),
            name: .AVPlayerItemTimeJumped,
            object: currentItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerStateChanged),
            name: .AVPlayerItemPlaybackStalled,
            object: currentItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerStateChanged),
            name: .AVPlayerItemDidPlayToEndTime,
            object: currentItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerStateChanged),
            name: .AVPlayerItemFailedToPlayToEndTime,
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
                    previewDelegate.readyToPlay(self)
                default:
                    previewDelegate.errorWhilePreviewing(self, error: ErrorDomain.incompatibleFile)
                }
            }
        }
    }
}
