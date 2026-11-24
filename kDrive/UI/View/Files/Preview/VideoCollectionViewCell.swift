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
    @LazyInjectService private var matomo: MatomoUtils

    static let identifier = String(describing: VideoCollectionViewCell.self)

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
    private var areControlsVisible = true

    private var pipController: AVPictureInPictureController?

    private let previewFrameImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

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

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        contentView.addSubview(previewFrameImageView)
        contentView.insertSubview(playerLayerView, belowSubview: previewFrameImageView)
        contentView.addSubview(loadingIndicator)
        contentView.addSubview(controlsView)

        let controlsLeftConstraint = controlsView.leftAnchor.constraint(equalTo: leftAnchor)
        let controlsRightConstraint = controlsView.rightAnchor.constraint(equalTo: rightAnchor)
        let controlsBottomConstraint = controlsView.bottomAnchor.constraint(equalTo: bottomAnchor)
        self.controlsLeftConstraint = controlsLeftConstraint
        self.controlsRightConstraint = controlsRightConstraint
        self.controlsBottomConstraint = controlsBottomConstraint

        NSLayoutConstraint.activate([
            previewFrameImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewFrameImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            previewFrameImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewFrameImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            playerLayerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerLayerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            playerLayerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerLayerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            controlsLeftConstraint,
            controlsRightConstraint,
            controlsBottomConstraint
        ])

        controlsView.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }

        controlsView.onSeek = { [weak self] progress in
            guard let self, let player else { return }
            let duration = player.currentItem?.duration ?? .zero
            let newTime = CMTimeMultiplyByFloat64(duration, multiplier: Float64(progress))
            player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: playerLayerView.playerLayer)
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        videoPlayer?.stopPlayback()
        removeInlinePlayer()
        isCurrentPage = false
        previewFrameImageView.image = nil
    }

    override func layoutSubviews() {
        updateControlsLayout()
        super.layoutSubviews()
    }

    override func configureWith(file: File) {
        assert(file.realm == nil || file.isFrozen, "File must be thread safe at this point")

        self.file = file
        file.getThumbnail(publicShareProxy: driveFileManager?.publicShareProxy) { preview, hasThumbnail in
            self.previewFrameImageView.image = hasThumbnail ? preview : nil
            self.videoPlayer?.thumbnail = self.previewFrameImageView.image
        }

        showLoadingIndicatorAfterDelay()

        videoPlayer = VideoPlayer(
            frozenFile: file,
            driveFileManager: driveFileManager,
            previewDelegate: self,
            thumbnail: previewFrameImageView.image
        )
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
                videoPlayer?.play()
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

    private func configureSubtitlesButton(
        _ button: UIButton,
        player: VideoPlayer
    ) {
        button.setImage(UIImage(systemName: "captions.bubble"), for: .normal)
        button.showsMenuAsPrimaryAction = true

        button.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                guard let self else {
                    completion([])
                    return
                }

                completion(self.getSubtitlesActions(player: player))
            }
        ])

        button.isHidden = player.subtitleGroup?.options.isEmpty != false
    }

    private func getSubtitlesActions(player: VideoPlayer) -> [UIAction] {
        guard let avPlayer = player.avPlayer, let item = avPlayer.currentItem,
              let group = player.subtitleGroup
        else {
            return []
        }

        let selectedLanguage = item.currentMediaSelection
            .selectedMediaOption(in: group)

        var actions = [UIAction]()

        if group.allowsEmptySelection {
            actions.append(UIAction(
                title: KDriveResourcesStrings.Localizable.allDisabled,
                state: selectedLanguage == nil ? .on : .off
            ) { _ in
                guard avPlayer.currentItem === item else { return }
                item.select(nil, in: group)
            })
        }

        actions += group.options.map { option in
            UIAction(
                title: option.displayName,
                state: selectedLanguage == option ? .on : .off
            ) { _ in
                guard avPlayer.currentItem === item else { return }
                item.select(option, in: group)
            }
        }

        return actions
    }

    private func embedInline() {
        guard player == nil, let videoPlayer, let player = videoPlayer.avPlayer else { return }

        configureSubtitlesButton(controlsView.subtitlesButton, player: videoPlayer)

        self.player = player
        playerLayerView.player = player

        if playerLayerView.playerLayer.isReadyForDisplay || videoPlayer.isAudioOnly == true {
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

    private func updateControlsVisibility(animated: Bool) {
        let isVisible = isPlayerRevealed && !(previewDelegate?.isFullscreenPreview ?? false)
        areControlsVisible = isVisible
        if isVisible {
            updateControlsLayout()
            controlsView.isHidden = false
        }
        UIView.animate(withDuration: animated ? 0.2 : 0) {
            self.controlsView.alpha = isVisible ? 1 : 0
        } completion: { _ in
            guard !self.areControlsVisible else { return }
            self.controlsView.isHidden = true
        }
    }

    override func updateControlsLayout() {
        guard areControlsVisible else { return }
        super.updateControlsLayout()
    }

    private func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus != .paused {
            player.pause()
        } else {
            if let item = player.currentItem,
               item.duration.seconds.isFinite,
               item.currentTime() >= item.duration {
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            videoPlayer?.play()
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
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player = nil
        playerLayerView.player = nil
        playerLayerView.alpha = 0
        controlsView.reset()
        updateControlsVisibility(animated: false)
        previewFrameImageView.alpha = 1
        tapGestureRecognizer.isEnabled = true
    }
}
