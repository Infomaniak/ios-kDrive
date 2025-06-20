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
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import Kingfisher
import MediaPlayer
import UIKit

class VideoCollectionViewCell: PreviewCollectionViewCell, VideoViewCellDelegate {
    private class VideoPlayerNavigationController: UINavigationController {
        var disappearCallback: (() -> Void)?

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            disappearCallback?()
        }
    }

    @IBOutlet var previewFrameImageView: UIImageView!
    @IBOutlet var playButton: UIButton!

    @LazyInjectService private var matomo: MatomoUtils

    var driveFileManager: DriveFileManager!
    weak var parentViewController: UIViewController?
    weak var floatingPanelController: FloatingPanelController?

    private var previewDownloadTask: Kingfisher.DownloadTask?
    private var file: File?
    private var videoPlayer: VideoPlayer?

    override func awakeFromNib() {
        super.awakeFromNib()
        playButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonPlayerPlayPause
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        videoPlayer?.stopPlayback()
        previewFrameImageView.image = nil
        previewDownloadTask?.cancel()
    }

    override func configureWith(file: File) {
        assert(file.realm == nil || file.isFrozen, "File must be thread safe at this point")

        self.file = file
        file.getThumbnail { preview, hasThumbnail in
            self.previewFrameImageView.image = hasThumbnail ? preview : nil
        }
        playButton.isEnabled = false

        videoPlayer = VideoPlayer(frozenFile: file, driveFileManager: driveFileManager, previewDelegate: self)
    }

    override func didEndDisplaying() {
        matomo.trackMediaPlayer(leaveAt: videoPlayer?.progressPercentage)
    }

    @IBAction func playVideoPressed(_ sender: Any) {
        guard let player = videoPlayer?.playerViewController.player else { return }

        matomo.trackMediaPlayer(playMedia: .video)

        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        guard let playerViewController = videoPlayer?.playerViewController else { return }
        playerViewController.canStartPictureInPictureAutomaticallyFromInline = true

        let navController = VideoPlayerNavigationController(rootViewController: playerViewController)
        navController.disappearCallback = { [weak self] in
            self?.matomo.track(eventWithCategory: .mediaPlayer, name: "pause")
            self?.videoPlayer?.stopPlayback()
            self?.presentFloatingPanel()
        }
        navController.setNavigationBarHidden(true, animated: false)
        navController.modalPresentationStyle = .overFullScreen
        navController.modalTransitionStyle = .crossDissolve

        presentFloatingPanel()
        parentViewController?.present(navController, animated: true) {
            playerViewController.player?.play()
        }
    }

    private func presentFloatingPanel() {
        if let floatingPanelController = parentViewController?.presentedViewController as? FloatingPanelController {
            floatingPanelController.dismiss(animated: true)
        }
    }

    func errorWhilePreviewing(error: any Error) {
        guard let file, let previewDelegate else { return }
        previewDelegate.errorWhilePreviewing(fileId: file.id, error: error)
        videoPlayer = nil
        playButton.isEnabled = false
    }

    func readyToPlay() {
        playButton.isEnabled = true
    }
}
