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
import FloatingPanel
import InfomaniakCore
import kDriveCore
import kDriveResources
import Kingfisher
import MediaPlayer
import UIKit
import Combine

class VideoPlayer {
    private var player: AVPlayer?
    var onPlaybackEnded: (() -> Void)?

    var avPlayer: AVPlayer? {
        return player
    }

    var progressPercentage: Double {
        guard let player = player else { return 0 }
        return player.currentTime().seconds / (player.currentItem?.duration.seconds ?? 1)
    }

    init(file: File, driveFileManager: DriveFileManager) {
        setupPlayer(with: file, driveFileManager: driveFileManager)
    }

    private func setupPlayer(with file: File, driveFileManager: DriveFileManager) {
        if !file.isLocalVersionOlderThanRemote {
            player = AVPlayer(url: file.localUrl)
        } else if let token = driveFileManager.apiFetcher.currentToken {
            driveFileManager.apiFetcher.performAuthenticatedRequest(token: token) { token, _ in
                if let token = token {
                    let url = Endpoint.download(file: file).url
                    let headers = ["Authorization": "Bearer \(token.accessToken)"]
                    let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                    Task { @MainActor in
                        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                        self.addPeriodicTimeObserver()
                    }
                }
            }
        }
    }

    private func addPeriodicTimeObserver() {
        guard let player = player else { return }
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidPlayToEnd), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }

    @objc private func playerDidPlayToEnd() {
        onPlaybackEnded?()
    }

    func setNowPlayingMetadata(playableFileName: String?) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
        nowPlayingInfo[MPMediaItemPropertyTitle] = playableFileName

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func stopPlayback() {
        player?.pause()
    }

    private func updateNowPlayingInfo() {
        guard let player = player else { return }

        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo

        nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(player.currentTime())
        nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = player.rate

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
