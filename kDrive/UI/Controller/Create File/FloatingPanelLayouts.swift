/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

import FloatingPanel
import kDriveCore
import kDriveResources
import UIKit

/// Layout used for a folder within a public share
class PublicShareFolderFloatingPanelLayout: FloatingPanelLayout {
    var position: FloatingPanelPosition = .bottom
    var initialState: FloatingPanelState = .tip
    var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring]
    private var backdropAlpha: CGFloat

    init(initialState: FloatingPanelState = .tip, hideTip: Bool = false, safeAreaInset: CGFloat = 0, backdropAlpha: CGFloat = 0) {
        self.initialState = initialState
        self.backdropAlpha = backdropAlpha
        let extendedAnchor = FloatingPanelLayoutAnchor(
            absoluteInset: 140.0 + safeAreaInset,
            edge: .bottom,
            referenceGuide: .superview
        )
        anchors = [
            .full: extendedAnchor,
            .half: extendedAnchor,
            .tip: FloatingPanelLayoutAnchor(absoluteInset: 86.0 + safeAreaInset, edge: .bottom, referenceGuide: .superview)
        ]
    }

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return backdropAlpha
    }
}

class PublicShareFileFloatingPanelLayout: FloatingPanelLayout {
    var position: FloatingPanelPosition = .bottom
    var initialState: FloatingPanelState = .tip
    var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring]
    private var backdropAlpha: CGFloat

    init(initialState: FloatingPanelState = .tip, hideTip: Bool = false, safeAreaInset: CGFloat = 0, backdropAlpha: CGFloat = 0) {
        self.initialState = initialState
        self.backdropAlpha = backdropAlpha
        let extendedAnchor = FloatingPanelLayoutAnchor(
            absoluteInset: 320.0 + safeAreaInset,
            edge: .bottom,
            referenceGuide: .superview
        )
        anchors = [
            .full: extendedAnchor,
            .half: extendedAnchor,
            .tip: FloatingPanelLayoutAnchor(absoluteInset: 86.0 + safeAreaInset, edge: .bottom, referenceGuide: .superview)
        ]
    }

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return backdropAlpha
    }
}

class FileFloatingPanelLayout: FloatingPanelLayout {
    var position: FloatingPanelPosition = .bottom
    var initialState: FloatingPanelState = .tip
    var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring]
    private var backdropAlpha: CGFloat

    init(initialState: FloatingPanelState = .tip, hideTip: Bool = false, safeAreaInset: CGFloat = 0, backdropAlpha: CGFloat = 0) {
        self.initialState = initialState
        self.backdropAlpha = backdropAlpha
        if hideTip {
            anchors = [
                .full: FloatingPanelLayoutAnchor(absoluteInset: 16.0, edge: .top, referenceGuide: .safeArea),
                .half: FloatingPanelLayoutAnchor(fractionalInset: 0.5, edge: .bottom, referenceGuide: .safeArea)
            ]
        } else {
            anchors = [
                .full: FloatingPanelLayoutAnchor(absoluteInset: 16.0, edge: .top, referenceGuide: .safeArea),
                .half: FloatingPanelLayoutAnchor(fractionalInset: 0.5, edge: .bottom, referenceGuide: .safeArea),
                .tip: FloatingPanelLayoutAnchor(absoluteInset: 86.0 + safeAreaInset, edge: .bottom, referenceGuide: .superview)
            ]
        }
    }

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return backdropAlpha
    }
}

class PlusButtonFloatingPanelLayout: FloatingPanelLayout {
    var position: FloatingPanelPosition = .bottom
    var height: CGFloat = 16

    init(height: CGFloat) {
        self.height = height
    }

    var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] {
        return [
            .full: FloatingPanelLayoutAnchor(absoluteInset: height, edge: .bottom, referenceGuide: .safeArea)
        ]
    }

    var initialState: FloatingPanelState = .full

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return 0.2
    }
}

class InformationViewFloatingPanelLayout: FloatingPanelLayout {
    var position: FloatingPanelPosition = .bottom

    var initialState: FloatingPanelState = .full

    var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] {
        return [
            .full: FloatingPanelIntrinsicLayoutAnchor(absoluteOffset: 0, referenceGuide: .safeArea)
        ]
    }

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return 0.3
    }
}
