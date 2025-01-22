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
import FloatingPanel
import InfomaniakCore
import InfomaniakDI
import kDriveResources
import MediaPlayer

public final class VideoPlayer: Pausable {
    @LazyInjectService private var orchestrator: MediaPlayerOrchestrator

    private var player: AVPlayer?
    private var asset: AVAsset?
    private var file: File?

    public var onPlaybackEnded: (() -> Void)?

    public var progressPercentage: Double {
        guard let player = player, let currentItem = player.currentItem else { return 0 }
        return player.currentTime().seconds / currentItem.duration.seconds
    }

    public var identifier: String = UUID().uuidString

    public lazy var playerViewController: AVPlayerViewController = {
        let playerViewController = AVPlayerViewController()
        playerViewController.player = self.player
        return playerViewController
    }()

    public init(frozenFile: File, driveFileManager: DriveFileManager) {
        setupPlayer(with: frozenFile, driveFileManager: driveFileManager)
        file = frozenFile
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
        guard let file else { return }
        guard let player else { return }
        updateMetadata(asset: asset, defaultName: file.name)

        guard player.timeControlStatus == .playing else { return }
        orchestrator.newPlaybackStarted(playable: self)
    }

    private func setupPlayer(with file: File, driveFileManager: DriveFileManager) {
        if !file.isLocalVersionOlderThanRemote {
            let localAsset = AVAsset(url: file.localUrl)
            asset = localAsset
            let playerItem = AVPlayerItem(asset: localAsset)
            player = AVPlayer(playerItem: playerItem)
            updateMetadata(asset: localAsset, defaultName: file.name)
            observePlayer(currentItem: playerItem)
        } else if let publicShareProxy = driveFileManager.publicShareProxy {
            let url = Endpoint.downloadShareLinkFile(
                driveId: publicShareProxy.driveId,
                linkUuid: publicShareProxy.shareLinkUid,
                fileId: file.id
            ).url

            let remoteAsset = AVURLAsset(url: url, options: nil)
            setupStreamingAsset(remoteAsset, fileName: file.name)

        } else if let token = driveFileManager.apiFetcher.currentToken {
            driveFileManager.apiFetcher.performAuthenticatedRequest(token: token) { token, _ in
                guard let token else { return }
                let url = Endpoint.download(file: file).url
                let headers = ["Authorization": "Bearer \(token.accessToken)"]
                let remoteAsset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                self.setupStreamingAsset(remoteAsset, fileName: file.name)
            }
        }
    }

    private func setupStreamingAsset(_ urlAsset: AVURLAsset, fileName: String) {
        asset = urlAsset
        Task { @MainActor in
            let playerItem = AVPlayerItem(asset: urlAsset)
            self.player = AVPlayer(playerItem: playerItem)
            self.updateMetadata(asset: urlAsset, defaultName: fileName)
            self.observePlayer(currentItem: playerItem)
        }
    }

    private func observePlayer(currentItem: AVPlayerItem) {
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
    }

    private func updateMetadata(asset: AVAsset?, defaultName: String) {
        guard let asset else { return }
        Task {
            let metadata = await MediaMetadata.extractTrackMetadata(from: asset.commonMetadata,
                                                                    playableFileName: defaultName)
            setNowPlayingMetadata(metadata: metadata)
        }
    }
}
