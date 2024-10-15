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
import FloatingPanel
import InfomaniakCore
import kDriveCore
import kDriveResources
import Kingfisher
import MediaPlayer
import UIKit

class VideoCollectionViewCell: PreviewCollectionViewCell {
    private class VideoPlayerNavigationController: UINavigationController {
        var disappearCallback: (() -> Void)?

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            disappearCallback?()
        }
    }

    @IBOutlet var previewFrameImageView: UIImageView!
    @IBOutlet var playButton: UIButton!

    var driveFileManager: DriveFileManager!
    weak var parentViewController: UIViewController?
    weak var floatingPanelController: FloatingPanelController?

    private var playableFileName: String?

    private var currentVideoMetadata: MediaMetadata?
    private var previewDownloadTask: Kingfisher.DownloadTask?
    private var file: File!
    private var player: AVPlayer? {
        didSet {
            playButton.isEnabled = player != nil
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        playButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonPlayerPlayPause
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        player?.pause()
        player = nil
        previewFrameImageView.image = nil
        previewDownloadTask?.cancel()
    }

    override func configureWith(file: File) {
        assert(file.realm == nil || file.isFrozen, "File must be thread safe at this point")

        self.file = file
        self.playableFileName = file.name
        file.getThumbnail { preview, hasThumbnail in
            self.previewFrameImageView.image = hasThumbnail ? preview : nil
        }
        if !file.isLocalVersionOlderThanRemote {
            player = AVPlayer(url: file.localUrl)
        } else if let token = driveFileManager.apiFetcher.currentToken {
            driveFileManager.apiFetcher.performAuthenticatedRequest(token: token) { token, _ in
                if let token {
                    let url = Endpoint.download(file: file).url
                    let headers = ["Authorization": "Bearer \(token.accessToken)"]
                    let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                    Task { @MainActor in
                        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                    }
                } else {
                    Task {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.previewLoadError)
                    }
                }
            }
        } else {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.previewLoadError)
        }
    }

    override func didEndDisplaying() {
        MatomoUtils.trackMediaPlayer(leaveAt: player?.progressPercentage)
    }

    @IBAction func playVideoPressed(_ sender: Any) {
        guard let player else { return }

        MatomoUtils.trackMediaPlayer(playMedia: .video)

        setNowPlayingMetadata()

        let playerViewController = AVPlayerViewController()
        playerViewController.player = player

        if #available(iOS 14.2, *) {
            playerViewController.canStartPictureInPictureAutomaticallyFromInline = true
        }

        let navController = VideoPlayerNavigationController(rootViewController: playerViewController)
        navController.disappearCallback = { [weak self] in
            MatomoUtils.track(eventWithCategory: .mediaPlayer, name: "pause")
            self?.player?.pause()
            if let floatingPanelController = self?.floatingPanelController {
                self?.parentViewController?.present(floatingPanelController, animated: true)
            }
        }
        navController.setNavigationBarHidden(true, animated: false)
        navController.modalPresentationStyle = .overFullScreen
        navController.modalTransitionStyle = .crossDissolve

        floatingPanelController = parentViewController?.presentedViewController as? FloatingPanelController
        floatingPanelController?.dismiss(animated: true)
        parentViewController?.present(navController, animated: true) {
            playerViewController.player?.play()
        }
    }

    private func setNowPlayingMetadata() {
        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false

        if let currentVideoMetadata {
            nowPlayingInfo[MPMediaItemPropertyTitle] = currentVideoMetadata.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = currentVideoMetadata.artist

            if let artwork = currentVideoMetadata.artwork {
                let artworkItem = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artworkItem
            }
        } else {
            nowPlayingInfo[MPMediaItemPropertyTitle] = playableFileName ?? ""
        }

        if let player = player, let currentItem = player.currentItem {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = CMTimeGetSeconds(currentItem.asset.duration)
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(player.currentTime())
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
