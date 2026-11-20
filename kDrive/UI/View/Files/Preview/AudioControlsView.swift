/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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

import kDriveResources
import UIKit

final class AudioControlsView: UIStackView {
    var onPlayPause: (() -> Void)?
    var onScrubbingBegan: (() -> Void)?
    var onSeek: ((TimeInterval) -> Void)?

    let playPauseButton = UIButton(type: .system)
    let elapsedTimeLabel = UILabel()
    let positionSlider = UISlider()
    let remainingTimeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        axis = .horizontal
        spacing = 8

        elapsedTimeLabel.textAlignment = .right
        for label in [elapsedTimeLabel, remainingTimeLabel] {
            label.font = MediaPlaybackStyle.timeLabelFont
            label.textColor = KDriveResourcesAsset.backgroundCardViewColor.color
        }

        positionSlider.maximumTrackTintColor = KDriveResourcesAsset.backgroundCardViewColor.color
        positionSlider.setThumbImage(
            MediaPlaybackStyle.sliderThumbImage(color: KDriveResourcesAsset.infomaniakColor.color),
            for: .normal
        )
        positionSlider.addTarget(self, action: #selector(sliderBeganTracking(_:)), for: .touchDown)
        positionSlider.addTarget(self, action: #selector(sliderEndedTracking(_:)), for: [.touchUpInside, .touchUpOutside])

        playPauseButton.setImage(KDriveResourcesAsset.play.image.withRenderingMode(.alwaysOriginal), for: .normal)
        playPauseButton.addTarget(self, action: #selector(playPausePressed), for: .touchUpInside)

        addArrangedSubview(playPauseButton)
        addArrangedSubview(elapsedTimeLabel)
        addArrangedSubview(positionSlider)
        addArrangedSubview(remainingTimeLabel)

        NSLayoutConstraint.activate([
            playPauseButton.widthAnchor.constraint(equalToConstant: 40),
            playPauseButton.heightAnchor.constraint(equalToConstant: 40),
            elapsedTimeLabel.widthAnchor.constraint(equalToConstant: 60),
            positionSlider.widthAnchor.constraint(equalToConstant: 264),
            remainingTimeLabel.widthAnchor.constraint(equalToConstant: 60)
        ])
    }

    @objc private func playPausePressed() {
        onPlayPause?()
    }

    @objc private func sliderBeganTracking(_ sender: UISlider) {
        onScrubbingBegan?()
    }

    @objc private func sliderEndedTracking(_ sender: UISlider) {
        onSeek?(TimeInterval(sender.value))
    }
}
