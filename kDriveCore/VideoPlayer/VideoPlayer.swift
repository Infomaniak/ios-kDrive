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

    public var onPlaybackEnded: (() -> Void)?

    public var progressPercentage: Double {
        guard let player = player, let currentItem = player.currentItem else { return 0 }
        return player.currentTime().seconds / currentItem.duration.seconds
    }

    private var player: AVPlayer?
    private var file: File?

    public lazy var playerViewController: AVPlayerViewController = {
        let playerViewController = AVPlayerViewController()
        playerViewController.player = self.player
        return playerViewController
    }()

    public init(frozenFile: File, driveFileManager: DriveFileManager) {
        setupPlayer(with: frozenFile, driveFileManager: driveFileManager)
        orchestrator.newPlaybackStarted(playable: self)
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
        guard let player = player else { return }
        guard let file else { return }

        if player.timeControlStatus == .playing {
            Task {
                let metadata = await MediaMetadata.extractTrackMetadata(from: file.localUrl,
                                                                        playableFileName: file.name)
                setNowPlayingMetadata(metadata: metadata)
            }
        }
    }

    private func setupPlayer(with file: File, driveFileManager: DriveFileManager) {
        if !file.isLocalVersionOlderThanRemote {
            player = AVPlayer(url: file.localUrl)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerStateChanged),
                name: .AVPlayerItemTimeJumped,
                object: player?.currentItem
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerStateChanged),
                name: .AVPlayerItemPlaybackStalled,
                object: player?.currentItem
            )
            Task { @MainActor in
                let currentTrackMetadata = await MediaMetadata.extractTrackMetadata(
                    from: file.localUrl,
                    playableFileName: file.name
                )
                setNowPlayingMetadata(metadata: currentTrackMetadata)
            }
        } else if let token = driveFileManager.apiFetcher.currentToken {
            driveFileManager.apiFetcher.performAuthenticatedRequest(token: token) { token, _ in
                if let token = token {
                    let url = Endpoint.download(file: file).url
                    let headers = ["Authorization": "Bearer \(token.accessToken)"]
                    let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                    Task { @MainActor in
                        let currentTrackMetadata = await MediaMetadata.extractTrackMetadata(
                            from: asset.url,
                            playableFileName: file.name
                        )
                        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                    }
                }
            }
        }
    }
}
