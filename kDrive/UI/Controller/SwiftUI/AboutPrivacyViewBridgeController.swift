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

import InfomaniakCoreCommonUI
import InfomaniakDI
import InfomaniakPrivacyManagement
import kDriveCore
import SwiftUI

enum AboutPrivacyViewBridgeController {
    static func instantiate() -> UIViewController {
        let swiftUIView = AboutPrivacyView()
        return UIHostingController(rootView: swiftUIView)
    }
}

struct AboutPrivacyView: View {
    @AppStorage(UserDefaults.shared.key(.matomoAuthorized)) private var matomoAuthorized = DefaultPreferences.matomoAuthorized

    var body: some View {
        PrivacyManagementView(
            urlRepository: URLConstants.sourceCode.url,
            backgroundColor: KDriveAsset.backgroundColor.swiftUIColor,
            illustration: KDriveAsset.documentSignaturePencilBulb.swiftUIImage,
            userDefaultStore: .shared,
            userDefaultKeyMatomo: UserDefaults.shared.key(.matomoAuthorized),
            userDefaultKeySentry: UserDefaults.shared.key(.sentryAuthorized)
        )
        .onChange(of: matomoAuthorized) { newValue in
            @InjectService var matomo: InfomaniakCoreCommonUI.MatomoUtils
            #if DEBUG || TEST
            matomo.optOut(true)
            #else
            matomo.optOut(!newValue)
            #endif
        }
    }
}

#Preview {
    AboutPrivacyView()
}
