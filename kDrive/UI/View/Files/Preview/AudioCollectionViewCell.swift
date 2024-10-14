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
import kDriveCore
import kDriveResources
import MediaPlayer
import UIKit

final class AudioCollectionViewCell: PreviewCollectionViewCell {
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var elapsedTimeLabel: UILabel!
    @IBOutlet var remainingTimeLabel: UILabel!
    @IBOutlet var positionSlider: UISlider!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var landscapePlayButton: UIButton!
    @IBOutlet var iconHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var songTitleLabel: UILabel!
    @IBOutlet weak var artistNameLabel: UILabel!

    var driveFileManager: DriveFileManager!

    public lazy var singleTrackPlayer = SingleTrackPlayer(driveFileManager: driveFileManager)

    private var cancellables = Set<AnyCancellable>()

    override func awakeFromNib() {
        super.awakeFromNib()
        // Change slider thumb
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        let circleImage = renderer.image { ctx in
            KDriveResourcesAsset.infomaniakColor.color.setFill()
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fill)
        }
        elapsedTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        remainingTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        positionSlider.setThumbImage(circleImage, for: .normal)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rotated),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        setControls(enabled: false)
    }

    @MainActor func setControls(enabled: Bool) {
        elapsedTimeLabel.text = CMTime.zeroTimeText
        remainingTimeLabel.text = CMTime.unknownTimeText
        positionSlider.value = 0.0
        playButton.isEnabled = enabled
        landscapePlayButton.isEnabled = enabled
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setControls(enabled: false)
        singleTrackPlayer.reset()
        songTitleLabel.text = ""
        artistNameLabel.text = ""
        iconImageView.image = nil
    }

    override func configureWith(file: File) {
        let frozenFile = file.freezeIfNeeded()
        setUpPlayButtons()

        Task { @MainActor in
            await singleTrackPlayer.setup(with: frozenFile)
            setControls(enabled: true)
            setupObservation()
        }
    }

    /// Setup data flow
    @MainActor func setupObservation() {
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
                self.elapsedTimeLabel.text = elapsedTime
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onRemainingTimeChange
            .receive(on: DispatchQueue.main)
            .sink { remainingTime in
                self.remainingTimeLabel.text = remainingTime
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onPositionChange
            .receive(on: DispatchQueue.main)
            .sink { newPosition in
                guard !self.positionSlider.isTracking else { return }
                self.positionSlider.setValue(newPosition, animated: true)
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onPositionMaximumChange
            .receive(on: DispatchQueue.main)
            .sink { sliderMaximum in
                self.positionSlider.maximumValue = sliderMaximum
            }
            .store(in: &cancellables)

        singleTrackPlayer
            .onCurrentTrackMetadata
            .receive(on: DispatchQueue.main)
            .sink { metadata in
                self.iconImageView.image = metadata.artwork
                self.artistNameLabel.text = metadata.artist
                self.songTitleLabel.text = metadata.title
            }
            .store(in: &cancellables)
    }

    @MainActor func setUpPlayButtons() {
        let isPortrait = (window?.windowScene?.interfaceOrientation.isPortrait ?? true)
        playButton.isHidden = !isPortrait
        landscapePlayButton.isHidden = isPortrait
        iconHeightConstraint.constant = isPortrait ? 254 : 120
    }

    @objc func rotated() {
        setUpPlayButtons()
    }

    @IBAction func playButtonPressed(_ sender: UIButton) {
        togglePlayPause()
    }

    @IBAction func sliderBeganTracking(_ sender: UISlider) {
        singleTrackPlayer.stopPlaybackObservation()
    }

    @IBAction func sliderEndedTracking(_ sender: UISlider) {
        seek(to: TimeInterval(sender.value))
    }

    override func didEndDisplaying() {
        MatomoUtils.trackMediaPlayer(leaveAt: singleTrackPlayer.progressPercentage)
        singleTrackPlayer.pause()
    }

    private func updateUI(state: SingleTrackPlayer.State) {
        if state == .playing {
            playButton?.setImage(KDriveResourcesAsset.pause.image, for: .normal)
            landscapePlayButton?.setImage(KDriveResourcesAsset.pause.image, for: .normal)
        } else {
            playButton?.setImage(KDriveResourcesAsset.play.image, for: .normal)
            landscapePlayButton?.setImage(KDriveResourcesAsset.play.image, for: .normal)
        }
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
