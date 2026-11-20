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
    private let playbackControls = AudioControlsView()
    private let playButton = UIButton(type: .system)
    private var containerLeadingConstraint: NSLayoutConstraint!
    private var containerTrailingConstraint: NSLayoutConstraint!
    private var stackBottomConstraint: NSLayoutConstraint!

    private var lastOrientationIsPortrait: Bool?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
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

        playbackControls.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        playbackControls.onScrubbingBegan = { [weak self] in
            self?.singleTrackPlayer.stopPlaybackObservation()
        }
        playbackControls.onSeek = { [weak self] position in
            self?.seek(to: position)
        }

        playButton.setImage(KDriveResourcesAsset.play.image.withRenderingMode(.alwaysOriginal), for: .normal)
        playButton.addTarget(self, action: #selector(playButtonPressed(_:)), for: .touchUpInside)
        let verticalStack = UIStackView(arrangedSubviews: [
            songTitleLabel,
            artistNameLabel,
            playbackControls,
            playButton
        ])
        verticalStack.axis = .vertical
        verticalStack.alignment = .center
        verticalStack.spacing = 8
        verticalStack.setCustomSpacing(2, after: songTitleLabel)
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
        containerLeadingConstraint = verticalStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24)
        containerTrailingConstraint = contentView.trailingAnchor.constraint(equalTo: verticalStack.trailingAnchor, constant: 24)
        stackBottomConstraint = verticalStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)

        NSLayoutConstraint.activate([
            containerLeadingConstraint,
            containerTrailingConstraint,
            stackBottomConstraint,

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

            playbackControls.leadingAnchor.constraint(greaterThanOrEqualTo: verticalStack.leadingAnchor),
            verticalStack.trailingAnchor.constraint(greaterThanOrEqualTo: playbackControls.trailingAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 70),
            playButton.heightAnchor.constraint(equalToConstant: 70)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rotated),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        setControls(enabled: false)
    }

    private func refreshHorizontalSafeInsets() {
        guard let window else { return }
        setHorizontalSafeInsets(left: window.safeAreaInsets.left, right: window.safeAreaInsets.right)
    }

    private func setHorizontalSafeInsets(left: CGFloat, right: CGFloat) {
        containerLeadingConstraint.constant = 24 + left
        containerTrailingConstraint.constant = 24 + right
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshHorizontalSafeInsets()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        refreshHorizontalSafeInsets()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateControlsLayout()
        setUpPlayButtons()
    }

    override func willDisplayInCollectionView() {
        super.willDisplayInCollectionView()
        updateControlsLayout()
    }

    private func updateControlsLayout() {
        let spacing = UIConstants.Padding.standard
        let safeFrame = safeAreaLayoutGuide.layoutFrame
        let bottom = safeFrame.maxY - (previewDelegate?.fileActionPanelHeight ?? 0) - spacing
        stackBottomConstraint.constant = bottom - bounds.maxY
    }

    @MainActor func setControls(enabled: Bool) {
        playbackControls.elapsedTimeLabel.text = CMTime.zeroTimeText
        playbackControls.remainingTimeLabel.text = CMTime.unknownTimeText
        playbackControls.positionSlider.value = 0.0
        playButton.isEnabled = enabled
        playbackControls.playPauseButton.isEnabled = enabled
        playButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonPlayerPlayPause
        playbackControls.playPauseButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonPlayerPlayPause
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailDownloadTask?.cancel()
        setControls(enabled: false)
        singleTrackPlayer.reset()
        songTitleLabel.text = ""
        artistNameLabel.text = ""
        artworkImageView.image = KDriveResourcesAsset.music.image
    }

    override func configureWith(file: File) {
        let frozenFile = file.freezeIfNeeded()

        Task { @MainActor in
            setupObservationFor(frozenFile: frozenFile)
            await singleTrackPlayer.setup(with: frozenFile)
            setControls(enabled: true)
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
                self.updateUI(state: newState)
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
            .onElapsedTimeChange
            .receive(on: DispatchQueue.main)
            .sink { elapsedTime in
                self.playbackControls.elapsedTimeLabel.text = elapsedTime
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onRemainingTimeChange
            .receive(on: DispatchQueue.main)
            .sink { remainingTime in
                self.playbackControls.remainingTimeLabel.text = remainingTime
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onPositionChange
            .receive(on: DispatchQueue.main)
            .sink { newPosition in
                guard !self.playbackControls.positionSlider.isTracking else { return }
                self.playbackControls.positionSlider.setValue(newPosition, animated: true)
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onPositionMaximumChange
            .receive(on: DispatchQueue.main)
            .sink { sliderMaximum in
                self.playbackControls.positionSlider.maximumValue = sliderMaximum
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

    private func setUpPlayButtons() {
        let isPortrait = (window?.windowScene?.interfaceOrientation.isPortrait ?? true)
        guard isPortrait != lastOrientationIsPortrait else { return }
        lastOrientationIsPortrait = isPortrait
        playButton.isHidden = !isPortrait
        playbackControls.playPauseButton.isHidden = isPortrait
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

    @objc private func rotated() {
        setUpPlayButtons()
    }

    @objc private func playButtonPressed(_ sender: UIButton) {
        togglePlayPause()
    }

    override func didEndDisplaying() {
        matomo.trackMediaPlayer(leaveAt: singleTrackPlayer.progressPercentage)
        singleTrackPlayer.pause()
    }

    private func updateUI(state: SingleTrackPlayer.State) {
        let image = state == .playing ? KDriveResourcesAsset.pause.image : KDriveResourcesAsset.play.image
        playButton.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
        playbackControls.playPauseButton.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
    }

    func play() {
        singleTrackPlayer.play()
    }

    func pause() {
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

    func skipForward(by interval: TimeInterval) {
        singleTrackPlayer.skipForward(by: interval)
    }

    func skipBackward(by interval: TimeInterval) {
        singleTrackPlayer.skipBackward(by: interval)
    }

    func setPlaybackRate(_ rate: Float) {
        singleTrackPlayer.setPlaybackRate(rate)
    }
}
