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
    var onSeek: ((Float) -> Void)?

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
    private var scrubbingTouch: UITouch?
    private var lastScrubbingActivity = Date.distantPast
    private var isScrubbing = false

    private var airPlayButton: AVRoutePickerView = {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        return view
    }()

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
        if isScrubbing {
            guard scrubbingHasEnded else { return }
            endScrubbing()
        }
        updateLabels(currentTime: currentTime)
        let totalSeconds = duration.seconds
        positionSlider.isEnabled = totalSeconds.isFinite && totalSeconds > 0
        positionSlider.value = positionSlider.isEnabled ? Float(currentTime.seconds / totalSeconds) : 0
    }

    func reset() {
        duration = .indefinite
        isScrubbing = false
        scrubbingTouch = nil
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
            label.font = MediaPlaybackStyle.timeLabelFont
            label.textColor = .white
        }

        positionSlider.minimumTrackTintColor = .white
        positionSlider.maximumTrackTintColor = .white.withAlphaComponent(0.3)
        positionSlider.setThumbImage(MediaPlaybackStyle.sliderThumbImage(color: .white), for: .normal)
        positionSlider.addTarget(self, action: #selector(sliderBeganTracking(_:event:)), for: .touchDown)
        positionSlider.addTarget(self, action: #selector(sliderValueChanged(_:event:)), for: .valueChanged)
        positionSlider.addTarget(self, action: #selector(sliderEndedTracking),
                                 for: [.touchUpInside, .touchUpOutside, .touchCancel])

        let stackView = UIStackView(arrangedSubviews: [
            playPauseButton,
            elapsedTimeLabel,
            positionSlider,
            remainingTimeLabel,
            airPlayButton
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
            stackView.heightAnchor.constraint(equalToConstant: 48),

            playPauseButton.widthAnchor.constraint(equalToConstant: 40),
            playPauseButton.heightAnchor.constraint(equalToConstant: 40),

            airPlayButton.widthAnchor.constraint(equalToConstant: 40),
            airPlayButton.heightAnchor.constraint(equalToConstant: 40)
        ])

        reset()
    }

    private func updateLabels(currentTime: CMTime) {
        elapsedTimeLabel.text = currentTime.formattedText
        remainingTimeLabel.text = currentTime.remainingTimeText(until: duration)
    }

    @objc private func playPausePressed() {
        onPlayPause?()
    }

    @objc private func sliderBeganTracking(_: UISlider, event: UIEvent?) {
        beginScrubbing(event: event)
    }

    @objc private func sliderValueChanged(_ slider: UISlider, event: UIEvent?) {
        beginScrubbing(event: event)
        let previewTime = CMTimeMultiplyByFloat64(duration, multiplier: Float64(slider.value))
        updateLabels(currentTime: previewTime)
        if scrubbingHasEnded {
            endScrubbing()
        }
    }

    @objc private func sliderEndedTracking() {
        endScrubbing()
    }

    private func beginScrubbing(event: UIEvent?) {
        if !isScrubbing {
            scrubbingTouch = nil
        }
        isScrubbing = true
        lastScrubbingActivity = Date()
        if let touch = event?.allTouches?.first {
            scrubbingTouch = touch
        }
    }

    private var scrubbingHasEnded: Bool {
        if let scrubbingTouch {
            return scrubbingTouch.phase == .ended || scrubbingTouch.phase == .cancelled
        }
        return Date().timeIntervalSince(lastScrubbingActivity) > 1
    }

    private func endScrubbing() {
        guard isScrubbing else { return }
        isScrubbing = false
        scrubbingTouch = nil
        onSeek?(positionSlider.value)
    }
}
