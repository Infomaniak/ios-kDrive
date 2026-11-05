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
    @IBOutlet var previewFrameImageView: UIImageView!

    @LazyInjectService private var matomo: MatomoUtils

    var driveFileManager: DriveFileManager!

    private var file: File?
    private var videoPlayer: VideoPlayer?
    private var player: AVPlayer?
    private var readyForDisplayObserver: NSKeyValueObservation?
    private var playbackStatusObserver: NSKeyValueObservation?
    private var timeObserver: Any?
    private var isCurrentPage = false
    private var isPlayerRevealed = false
    private var needsStartFromBeginning = true

    private var loadingIndicatorTask: Task<Void, Never>?
    private var controlsBottomConstraint: NSLayoutConstraint?
    private var areControlsVisible = true

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = KDriveResourcesAsset.loaderDarkerDefaultColor.color
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let playerLayerView: PlayerLayerView = {
        let view = PlayerLayerView()
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let controlsView: VideoControlsView = {
        let view = VideoControlsView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func awakeFromNib() {
        super.awakeFromNib()

        let container = previewFrameImageView.superview ?? contentView
        container.insertSubview(playerLayerView, belowSubview: previewFrameImageView)
        container.addSubview(loadingIndicator)
        container.addSubview(controlsView)

        let controlsBottomConstraint = controlsView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        self.controlsBottomConstraint = controlsBottomConstraint
        let controlsPreferredWidth = controlsView.widthAnchor.constraint(
            equalTo: container.safeAreaLayoutGuide.widthAnchor,
            constant: -2 * UIConstants.Padding.medium
        )

        NSLayoutConstraint.activate([
            playerLayerView.topAnchor.constraint(equalTo: container.topAnchor),
            playerLayerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            playerLayerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            playerLayerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            controlsView.centerXAnchor.constraint(equalTo: container.safeAreaLayoutGuide.centerXAnchor),
            controlsPreferredWidth,
            controlsBottomConstraint
        ])

        controlsView.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        videoPlayer?.stopPlayback()
        removeInlinePlayer()
        isCurrentPage = false
        previewFrameImageView.image = nil
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
        guard isCurrentPage, let player else { return false }
        return player.rate != 0
    }

    override func didStartDisplaying() {
        guard !isCurrentPage else { return }
        isCurrentPage = true
        if isPlayerRevealed {
            if needsStartFromBeginning {
                startFromBeginning()
            } else {
                player?.play()
            }
        }
    }

    override func didEndDisplaying() {
        matomo.trackMediaPlayer(leaveAt: videoPlayer?.progressPercentage)
        isCurrentPage = false
        videoPlayer?.stopPlayback()
    }

    override func didLeavePage() {
        needsStartFromBeginning = true
        player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    override func fullscreenDidChange() {
        updateControlsVisibility(animated: true)
    }

    override func willDisplayInCollectionView() {
        guard let videoPlayer, videoPlayer.isReadyToPlay else { return }
        readyToPlay(videoPlayer)
    }

    override func didEndDisplayingInCollectionView() {
        isCurrentPage = false
        videoPlayer?.stopPlayback()
        removeInlinePlayer()
    }

    func errorWhilePreviewing(_ videoPlayer: VideoPlayer, error: any Error) {
        guard videoPlayer === self.videoPlayer else { return }
        hideLoadingIndicator()
        guard let file, let previewDelegate else { return }
        previewDelegate.errorWhilePreviewing(fileId: file.id, error: error)
        self.videoPlayer = nil
    }

    func readyToPlay(_ videoPlayer: VideoPlayer) {
        guard videoPlayer === self.videoPlayer else { return }
        embedInline()
    }

    private func embedInline() {
        guard player == nil, let player = videoPlayer?.avPlayer else { return }

        self.player = player
        playerLayerView.player = player

        if playerLayerView.playerLayer.isReadyForDisplay || videoPlayer?.isAudioOnly == true {
            revealPlayer()
        } else {
            readyForDisplayObserver = playerLayerView.playerLayer
                .observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] _, change in
                    guard change.newValue == true else { return }
                    Task { @MainActor in
                        guard let self, self.player === player, !self.isPlayerRevealed else { return }
                        self.readyForDisplayObserver = nil
                        self.revealPlayer()
                    }
                }
        }
        observePlaybackStatus(of: player)
    }

    private func revealPlayer() {
        isPlayerRevealed = true
        if isCurrentPage {
            startFromBeginning()
        }

        loadingIndicatorTask?.cancel()
        UIView.animate(withDuration: 0.25) {
            self.playerLayerView.alpha = 1
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

    private func observePlaybackStatus(of player: AVPlayer) {
        playbackStatusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor in
                guard let self, self.isCurrentPage, self.player === player else { return }
                self.controlsView.setPlaying(status != .paused)
                switch status {
                case .playing:
                    self.previewDelegate?.setPlaybackFullscreen(true)
                case .paused:
                    self.previewDelegate?.setPlaybackFullscreen(false)
                default:
                    return
                }
            }
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self, weak player] time in
            MainActor.assumeIsolated {
                guard let self, let player, self.player === player else { return }
                self.controlsView.update(currentTime: time, duration: player.currentItem?.duration ?? .indefinite)
            }
        }
    }

    private func updatePlayerBottomInset(_ playerViewController: AVPlayerViewController) {
        let bottomInset = previewDelegate?.fileActionPanelHeight ?? 0
        guard playerViewController.additionalSafeAreaInsets.bottom != bottomInset else { return }
        UIView.animate(withDuration: 0.25) {
            playerViewController.additionalSafeAreaInsets.bottom = bottomInset
            playerViewController.view.layoutIfNeeded()
        }
    }

    private func updateControlsVisibility(animated: Bool) {
        let isVisible = isPlayerRevealed && !(previewDelegate?.isFullscreenPreview ?? false)
        areControlsVisible = isVisible
        if isVisible {
            updateControlsBottomInset()
            controlsView.isHidden = false
        }
        UIView.animate(withDuration: animated ? 0.2 : 0) {
            controlsView.alpha = isVisible ? 1 : 0
        } completion: { _ in
            guard !self.areControlsVisible else { return }
            self.controlsView.isHidden = true
        }
    }

    private func updateControlsBottomInset() {
        guard areControlsVisible, let controlsBottomConstraint else { return }
        let bottomInset = previewDelegate?.fileActionPanelHeight ?? 0
        guard controlsBottomConstraint.constant != -bottomInset else { return }
        controlsBottomConstraint.constant = -bottomInset
    }

    private func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    private func startFromBeginning() {
        guard let player else { return }
        matomo.trackMediaPlayer(playMedia: .video)
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        needsStartFromBeginning = false
        updateControlsVisibility(animated: true)
    }

    private func removeInlinePlayer() {
        readyForDisplayObserver = nil
        playbackStatusObserver = nil
        isPlayerRevealed = false
        needsStartFromBeginning = true
        player = nil
        playerLayerView.player = nil
        playerLayerView.alpha = 0
        controlsView.reset()
        previewFrameImageView.alpha = 1
        tapGestureRecognizer.isEnabled = true
    }
}
