/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakCoreSwiftUI
import InfomaniakDI
import kDriveResources
import SwiftUI

enum AskForReviewBridgeController {
    static func instantiate(onDislike: @escaping () -> Void) -> UIViewController {
        @LazyInjectService var reviewManager: ReviewManageable
        @InjectService var matomo: MatomoUtils

        weak var weakHostingController: UIHostingController<AlertView<AskForReviewView>>?
        let rootView = AlertView(backgroundColor: Color(KDriveResourcesAsset.backgroundCardViewColor.color)) {
            AskForReviewView(
                appName: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String,
                reviewManager: reviewManager,
                onLike: {
                    matomo.track(eventWithCategory: .appReview, name: "like")
                    DispatchQueue.main.async {
                        weakHostingController?.dismiss(animated: true)
                    }
                },
                onDislike: {
                    DispatchQueue.main.async {
                        weakHostingController?.dismiss(animated: true, completion: onDislike)
                    }
                }
            )
        }

        let hostingController = UIHostingController(rootView: rootView)
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.view.backgroundColor = .clear
        weakHostingController = hostingController
        return hostingController
    }
}
