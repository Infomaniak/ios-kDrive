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

import Combine
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import MediaPlayer
import Nuke
import UIKit

final class AudioCollectionViewCell: PreviewCollectionViewCell {
    static let identifier = String(describing: AudioCollectionViewCell.self)

    @LazyInjectService private var matomo: MatomoUtils

    var driveFileManager: DriveFileManager!

    lazy var singleTrackPlayer = SingleTrackPlayer(driveFileManager: driveFileManager)

    private var cancellables = Set<AnyCancellable>()
    private var thumbnailDownloadTask: ImageTask?

    private let artworkImageView = UIImageView(image: KDriveResourcesAsset.music.image)
    private let songTitleLabel = IKLabel(frame: .zero)
    private let artistNameLabel = IKLabel(frame: .zero)
    private var containerLeadingConstraint: NSLayoutConstraint!
    private var containerTrailingConstraint: NSLayoutConstraint!

    private var currentDuration: CMTime = .indefinite

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let controlsView: VideoControlsView = {
        let view = VideoControlsView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private func setupView() {
        tapGestureRecognizer.isEnabled = false

        artworkImageView.contentMode = .scaleAspectFit
        artworkImageView.isAccessibilityElement = false
        artworkImageView.setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
        artworkImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        songTitleLabel.style = .header1Light
        songTitleLabel.text = ""
        songTitleLabel.setContentHuggingPriority(.required, for: .vertical)

        artistNameLabel.style = .body1Light
        artistNameLabel.text = ""
        artistNameLabel.setContentHuggingPriority(.required, for: .vertical)

        controlsView.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        controlsView.onSeek = { [weak self] progress in
            guard let self, currentDuration.seconds.isFinite, currentDuration.seconds > 0 else { return }
            seek(to: CMTimeMultiplyByFloat64(currentDuration, multiplier: Float64(progress)))
        }

        let verticalStack = UIStackView(arrangedSubviews: [
            songTitleLabel,
            artistNameLabel,
            controlsView
        ])
        controlsView.subtitlesButton.isHidden = true
        controlsView.airPlayButton.isHidden = true
        verticalStack.axis = .vertical
        verticalStack.alignment = .center
        verticalStack.spacing = 8
        verticalStack.setCustomSpacing(24, after: artistNameLabel)
        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        artworkImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(verticalStack)
        contentView.addSubview(artworkImageView)

        let artworkLayoutGuide = UILayoutGuide()
        contentView.addLayoutGuide(artworkLayoutGuide)

        let preferredArtworkHeight = artworkImageView.heightAnchor.constraint(
            equalTo: artworkLayoutGuide.heightAnchor,
            multiplier: 0.75
        )
        preferredArtworkHeight.priority = .defaultLow

        let controlsLeftConstraint = controlsView.leftAnchor.constraint(equalTo: leftAnchor)
        let controlsRightConstraint = controlsView.rightAnchor.constraint(equalTo: rightAnchor)
        let controlsBottomConstraint = controlsView.bottomAnchor.constraint(equalTo: bottomAnchor)
        self.controlsLeftConstraint = controlsLeftConstraint
        self.controlsRightConstraint = controlsRightConstraint
        self.controlsBottomConstraint = controlsBottomConstraint

        NSLayoutConstraint.activate([
            controlsLeftConstraint,
            controlsRightConstraint,
            controlsBottomConstraint,

            artworkLayoutGuide.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor),
            artworkLayoutGuide.bottomAnchor.constraint(equalTo: songTitleLabel.topAnchor),

            artworkImageView.centerXAnchor.constraint(equalTo: verticalStack.centerXAnchor),
            artworkImageView.centerYAnchor.constraint(equalTo: artworkLayoutGuide.centerYAnchor),
            artworkImageView.widthAnchor.constraint(equalTo: artworkImageView.heightAnchor),
            preferredArtworkHeight,

            artworkImageView.heightAnchor.constraint(lessThanOrEqualTo: artworkLayoutGuide.heightAnchor, multiplier: 0.75),
            artworkImageView.widthAnchor.constraint(
                lessThanOrEqualTo: contentView.safeAreaLayoutGuide.widthAnchor,
                multiplier: 0.7
            ),

            controlsView.leadingAnchor.constraint(equalTo: verticalStack.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: verticalStack.trailingAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateControlsLayout()
    }

    override func willDisplayInCollectionView() {
        super.willDisplayInCollectionView()
        updateControlsLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailDownloadTask?.cancel()
        controlsView.reset()
        singleTrackPlayer.reset()
        currentDuration = .indefinite
        songTitleLabel.text = ""
        artistNameLabel.text = ""
        artworkImageView.image = KDriveResourcesAsset.music.image
    }

    override func configureWith(file: File) {
        let frozenFile = file.freezeIfNeeded()

        Task { @MainActor in
            setupObservationFor(frozenFile: frozenFile)
            await singleTrackPlayer.setup(with: frozenFile)
        }
    }

    /// Setup data flow
    @MainActor func setupObservationFor(frozenFile: File) {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        singleTrackPlayer
            .onPlayerStateChange
            .receive(on: DispatchQueue.main)
            .sink { newState in
                self.controlsView.setPlaying(newState == .playing)
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onPlaybackError
            .receive(on: DispatchQueue.main)
            .sink { _ in
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.previewLoadError)
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onPositionChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newPosition in
                guard let self else { return }
                controlsView.update(
                    currentTime: CMTime(seconds: Double(newPosition), preferredTimescale: 1), duration: currentDuration
                )
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onPositionMaximumChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sliderMaximum in
                guard let self else { return }
                currentDuration = CMTime(seconds: Double(sliderMaximum), preferredTimescale: 1)
                controlsView.update(currentTime: .zero, duration: currentDuration)
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onCurrentTrackMetadata
            .receive(on: DispatchQueue.main)
            .sink { metadata in
                self.handleMetadata(metadata, file: frozenFile)
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onItemError
            .receive(on: DispatchQueue.main)
            .sink { error in
                self.previewDelegate?.errorWhilePreviewing(fileId: frozenFile.id, error: error)
            }
            .store(in: &cancellables)
    }

    func handleMetadata(_ metadata: MediaMetadata, file: File) {
        if let artwork = metadata.artwork {
            artworkImageView.image = artwork
        } else {
            artworkImageView.image = KDriveResourcesAsset.music.image
            thumbnailDownloadTask = file.getThumbnail(publicShareProxy: driveFileManager.publicShareProxy) {
                thumbnail, isThumbnailAvailable in
                guard isThumbnailAvailable else { return }
                self.artworkImageView.image = thumbnail
            }
        }
        artistNameLabel.text = metadata.artist
        songTitleLabel.text = metadata.title
    }

    override func didStartDisplaying() {
        super.didStartDisplaying()
        if previewDelegate?.isFullscreenPreview == true {
            previewDelegate?.setFullscreen(false)
        }
    }

    override func didEndDisplaying() {
        matomo.trackMediaPlayer(leaveAt: singleTrackPlayer.progressPercentage)
        singleTrackPlayer.pause()
    }

    func togglePlayPause() {
        singleTrackPlayer.togglePlayPause()
    }

    func seek(to time: CMTime) {
        singleTrackPlayer.seek(to: time)
    }

    func seek(to position: TimeInterval) {
        singleTrackPlayer.seek(to: position)
    }
}
