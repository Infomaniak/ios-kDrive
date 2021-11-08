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

import Foundation
import UIKit

extension UIApplication {
    var keyWindow: UIWindow? {
        let allScenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        // We want to have at least one foreground scene but we prefer active scenes rather than inactive ones
        let foregroundScenes = allScenes.filter { $0.activationState == .foregroundActive } + allScenes.filter { $0.activationState == .foregroundInactive }
        let firstForegroundWindow = foregroundScenes.flatMap(\.windows).first(where: \.isKeyWindow)
        return firstForegroundWindow
    }
}
