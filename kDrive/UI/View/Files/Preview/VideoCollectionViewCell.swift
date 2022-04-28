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
import UIKit

class VideoCollectionViewCell: PreviewCollectionViewCell {
    private class VideoPlayerNavigationController: UINavigationController {
        var disappearCallback: (() -> Void)?

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            disappearCallback?()
        }
    }

    @IBOutlet weak var previewFrameImageView: UIImageView!
    @IBOutlet weak var playButton: UIButton!

    var driveFileManager: DriveFileManager!
    weak var parentViewController: UIViewController?
    weak var floatingPanelController: FloatingPanelController?

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
        self.file = file
        file.getThumbnail { preview, hasThumbnail in
            self.previewFrameImageView.image = hasThumbnail ? preview : nil
        }
        if !file.isLocalVersionOlderThanRemote {
            player = AVPlayer(url: file.localUrl)
        } else if let token = driveFileManager.apiFetcher.currentToken {
            driveFileManager.apiFetcher.performAuthenticatedRequest(token: token) { token, _ in
                if let token = token {
                    let url = Endpoint.download(file: file).url
                    let headers = ["Authorization": "Bearer \(token.accessToken)"]
                    let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                    DispatchQueue.main.async {
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
        guard let player = player else { return }

        MatomoUtils.trackMediaPlayer(playMedia: .video)

        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
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
}
