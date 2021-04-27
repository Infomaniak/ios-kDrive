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
import kDriveCore
import AVKit
import Kingfisher

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
    private var previewDownloadTask: Kingfisher.DownloadTask?
    private var file: File!
    private var player: AVPlayer!
    var parentViewController: UIViewController?

    override func awakeFromNib() {
        super.awakeFromNib()
        playButton.accessibilityLabel = KDriveStrings.Localizable.buttonPlayerPlayPause
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        player.pause()
        player = nil
        previewFrameImageView.image = nil
        previewDownloadTask?.cancel()
    }

    override func configureWith(file: File) {
        self.file = file
        file.getThumbnail { (preview, hasThumbnail) in
            self.previewFrameImageView.image = hasThumbnail ? preview : nil
        }
        let url: AVURLAsset
        if !file.isLocalVersionOlderThanRemote() {
            url = AVURLAsset(url: file.localUrl)
        } else {
            let headers = ["Authorization": "Bearer \(AccountManager.instance.currentAccount.token.accessToken)"]
            url = AVURLAsset(url: URL(string: ApiRoutes.downloadFile(file: file))!, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        }
        player = AVPlayer(playerItem: AVPlayerItem(asset: url))

    }

    @IBAction func playVideoPressed(_ sender: Any) {
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        let navController = VideoPlayerNavigationController(rootViewController: playerViewController)
        navController.disappearCallback = {
            self.player.pause()
        }
        navController.setNavigationBarHidden(true, animated: false)
        navController.modalPresentationStyle = .overFullScreen
        navController.modalTransitionStyle = .crossDissolve

        parentViewController?.presentedViewController?.dismiss(animated: true)
        parentViewController?.present(navController, animated: true) {
            playerViewController.player?.play()
        }
    }

}
