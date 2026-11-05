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

import AVKit
import kDriveCore
import kDriveResources
import UIKit

final class VideoControlsView: UIView {
    var onPlayPause: (() -> Void)?

    private let backgroundView: UIVisualEffectView = {
        if #available(iOS 26.0, *) {
            return UIVisualEffectView(effect: UIGlassEffect())
        }
        return UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    }()

    private let playPauseButton = UIButton(type: .system)
    private let elapsedTimeLabel = UILabel()
    private let remainingTimeLabel = UILabel()
    private let positionSlider = UISlider()

    private var duration = CMTime.indefinite

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if #unavailable(iOS 26.0) {
            backgroundView.layer.cornerRadius = backgroundView.bounds.height / 2
        }
    }

    func setPlaying(_ isPlaying: Bool) {
        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: symbolName), for: .normal)
    }

    func update(currentTime: CMTime, duration: CMTime) {
        self.duration = duration
        updateLabels(currentTime: currentTime)
        let totalSeconds = duration.seconds
        positionSlider.isEnabled = totalSeconds.isFinite && totalSeconds > 0
        positionSlider.value = positionSlider.isEnabled ? Float(currentTime.seconds / totalSeconds) : 0
    }

    func reset() {
        duration = .indefinite
        positionSlider.value = 0
        positionSlider.isEnabled = false
        elapsedTimeLabel.text = CMTime.zeroTimeText
        remainingTimeLabel.text = CMTime.unknownTimeText
        setPlaying(false)
    }

    private func setupView() {
        overrideUserInterfaceStyle = .dark
        tintColor = .white

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 26.0, *) {
            backgroundView.cornerConfiguration = .capsule()
        } else {
            backgroundView.layer.cornerCurve = .continuous
            backgroundView.clipsToBounds = true
        }
        addSubview(backgroundView)

        playPauseButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonPlayerPlayPause
        playPauseButton.addTarget(self, action: #selector(playPausePressed), for: .touchUpInside)

        for label in [elapsedTimeLabel, remainingTimeLabel] {
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
            label.textColor = .white
        }

        positionSlider.minimumTrackTintColor = .white
        positionSlider.maximumTrackTintColor = .white.withAlphaComponent(0.3)
        positionSlider.setThumbImage(Self.circleImage, for: .normal)

        let stackView = UIStackView(arrangedSubviews: [
            playPauseButton,
            elapsedTimeLabel,
            positionSlider,
            remainingTimeLabel
        ])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = UIConstants.Padding.small
        stackView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor,
                                               constant: UIConstants.Padding.small),
            stackView.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor,
                                                constant: -UIConstants.Padding.small),
            stackView.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 52),

            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            playPauseButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        reset()
    }

    private func updateLabels(currentTime: CMTime) {
        elapsedTimeLabel.text = currentTime.formattedText
        let totalSeconds = duration.seconds
        guard totalSeconds.isFinite else {
            remainingTimeLabel.text = CMTime.unknownTimeText
            return
        }
        let remaining = max(duration - currentTime, .zero)
        remainingTimeLabel.text = "-\(remaining.formattedText)"
    }

    @objc private func playPausePressed() {
        onPlayPause?()
    }

    private static let circleImage: UIImage = {
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fill)
        }
    }()
}
