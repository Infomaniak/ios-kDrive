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
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import MediaPlayer
import Nuke
import UIKit

class VideoCollectionViewCell: PreviewCollectionViewCell, VideoViewCellDelegate {
    private class VideoPlayerNavigationController: UINavigationController {
        var disappearCallback: (() -> Void)?

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            disappearCallback?()
        }
    }

    @IBOutlet var previewFrameImageView: UIImageView!

    @LazyInjectService private var matomo: MatomoUtils

    var driveFileManager: DriveFileManager!
    weak var parentViewController: UIViewController?

    private var previewDownloadTask: ImageTask?
    private var file: File?
    private var videoPlayer: VideoPlayer?
    private var playerViewControllerIfLoaded: AVPlayerViewController?
    private var readyForDisplayObserver: NSKeyValueObservation?
    private var playbackStatusObserver: NSKeyValueObservation?
    private var isCurrentPage = false
    private var isPlayerRevealed = false

    private var loadingIndicatorTask: Task<Void, Never>?
    private let touchTracker = TouchTrackingGestureRecognizer()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = KDriveResourcesAsset.loaderDarkerDefaultColor.color
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    override func awakeFromNib() {
        super.awakeFromNib()

        let container = previewFrameImageView.superview ?? contentView
        container.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        videoPlayer?.stopPlayback()
        removeInlinePlayer()
        isCurrentPage = false
        previewFrameImageView.image = nil
        previewDownloadTask?.cancel()
    }

    override func configureWith(file: File) {
        assert(file.realm == nil || file.isFrozen, "File must be thread safe at this point")

        self.file = file
        file.getThumbnail(publicShareProxy: driveFileManager?.publicShareProxy) { preview, hasThumbnail in
            self.previewFrameImageView.image = hasThumbnail ? preview : nil
        }

        showLoadingIndicatorAfterDelay()

        videoPlayer = VideoPlayer(frozenFile: file, driveFileManager: driveFileManager, previewDelegate: self)
    }

    override var prefersFullscreenPreview: Bool {
        guard isCurrentPage, let player = playerViewControllerIfLoaded?.player else { return false }
        return player.rate != 0
    }

    override func didStartDisplaying() {
        guard !isCurrentPage else { return }
        isCurrentPage = true
        if isPlayerRevealed {
            playFromBeginning()
        }
    }

    override func didEndDisplaying() {
        matomo.trackMediaPlayer(leaveAt: videoPlayer?.progressPercentage)
        isCurrentPage = false
        videoPlayer?.stopPlayback()
        playerViewControllerIfLoaded?.player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func errorWhilePreviewing(error: any Error) {
        hideLoadingIndicator()
        guard let file, let previewDelegate else { return }
        previewDelegate.errorWhilePreviewing(fileId: file.id, error: error)
        videoPlayer = nil
    }

    func readyToPlay() {
        guard let parentViewController else { return }
        embedInline(in: parentViewController)
    }

    private func embedInline(in parent: UIViewController) {
        guard let playerViewController = videoPlayer?.playerViewController,
              playerViewController.parent == nil,
              let container = previewFrameImageView.superview else { return }

        playerViewControllerIfLoaded = playerViewController
        parent.addChild(playerViewController)

        let playerView: UIView = playerViewController.view
        playerView.alpha = 0
        playerView.translatesAutoresizingMaskIntoConstraints = false
        container.insertSubview(playerView, belowSubview: previewFrameImageView)
        NSLayoutConstraint.activate([
            playerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            playerView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            playerView.widthAnchor.constraint(equalTo: container.widthAnchor),
            playerView.heightAnchor.constraint(equalTo: container.heightAnchor)
        ])
        playerViewController.didMove(toParent: parent)
        observePlaybackStatus(of: playerViewController)

        if playerViewController.isReadyForDisplay {
            revealPlayer(playerViewController)
        } else {
            readyForDisplayObserver = playerViewController
                .observe(\.isReadyForDisplay, options: [.new]) { [weak self] _, change in
                    guard change.newValue == true else { return }
                    Task { @MainActor in
                        guard let self, self.playerViewControllerIfLoaded === playerViewController else { return }
                        self.readyForDisplayObserver = nil
                        self.revealPlayer(playerViewController)
                    }
                }
        }
    }

    private func revealPlayer(_ playerViewController: AVPlayerViewController) {
        isPlayerRevealed = true
        tapGestureRecognizer.isEnabled = false
        if isCurrentPage {
            playFromBeginning()
        }

        loadingIndicatorTask?.cancel()
        UIView.animate(withDuration: 0.25) {
            playerViewController.view.alpha = 1
            self.previewFrameImageView.alpha = 0
            self.loadingIndicator.alpha = 0
        } completion: { _ in
            self.hideLoadingIndicator()
        }
    }

    private func showLoadingIndicatorAfterDelay() {
        hideLoadingIndicator()
        loadingIndicatorTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self, !self.isPlayerRevealed else { return }
            loadingIndicator.startAnimating()
        }
    }

    private func hideLoadingIndicator() {
        loadingIndicatorTask?.cancel()
        loadingIndicatorTask = nil
        loadingIndicator.stopAnimating()
        loadingIndicator.alpha = 1
    }

    private func observePlaybackStatus(of playerViewController: AVPlayerViewController) {
        playbackStatusObserver = playerViewController.player?
            .observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                let status = player.timeControlStatus
                Task { @MainActor in
                    guard let self, self.isCurrentPage, self.playerViewControllerIfLoaded === playerViewController else { return }
                    switch status {
                    case .playing:
                        self.previewDelegate?.setPlaybackFullscreen(true)
                        self.updatePlayerBottomInset(playerViewController)
                    case .paused:
                        guard !self.touchTracker.isTouching else { return }
                        self.previewDelegate?.setPlaybackFullscreen(false)
                        self.updatePlayerBottomInset(playerViewController)
                    default:
                        return
                    }
                }
            }
        playerViewController.view.addGestureRecognizer(touchTracker)
    }

    private func updatePlayerBottomInset(_ playerViewController: AVPlayerViewController) {
        let bottomInset = previewDelegate?.fileActionPanelHeight ?? 0
        guard playerViewController.additionalSafeAreaInsets.bottom != bottomInset else { return }
        UIView.animate(withDuration: 0.25) {
            playerViewController.additionalSafeAreaInsets.bottom = bottomInset
            playerViewController.view.layoutIfNeeded()
        }
    }

    private func playFromBeginning() {
        guard let player = playerViewControllerIfLoaded?.player else { return }
        matomo.trackMediaPlayer(playMedia: .video)
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
    }

    private func removeInlinePlayer() {
        readyForDisplayObserver = nil
        playbackStatusObserver = nil
        touchTracker.view?.removeGestureRecognizer(touchTracker)
        isPlayerRevealed = false
        if let playerViewController = playerViewControllerIfLoaded {
            playerViewController.additionalSafeAreaInsets.bottom = 0
            playerViewController.willMove(toParent: nil)
            playerViewController.view.removeFromSuperview()
            playerViewController.removeFromParent()
        }
        playerViewControllerIfLoaded = nil
        previewFrameImageView.alpha = 1
        tapGestureRecognizer.isEnabled = true
    }
}
