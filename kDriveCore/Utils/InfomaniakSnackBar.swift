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

import UIKit
import SnackBar


public class InfomaniakSnackBar: SnackBar {

    required init(contextView: UIView, message: String, duration: Duration) {
        super.init(contextView: contextView, message: message, duration: duration)
        self.addShadow(elevation: 6)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var style: SnackBarStyle {
        var style = SnackBarStyle()
        style.padding = 24
        style.background = KDriveCoreAsset.backgroundCardViewColor.color
        style.textColor = KDriveCoreAsset.titleColor.color
        style.actionTextColor = KDriveCoreAsset.infomaniakColor.color
        style.actionTextColorAlpha = 1
        style.actionFont = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .medium)
        return style
    }

    private static func getTopViewController() -> UIViewController? {
        let windows = UIApplication.shared.windows
        let keyWindow = windows.count == 1 ? windows.first : windows.filter(\.isKeyWindow).first
        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            return topController
        } else {
            return nil
        }
    }

    public static func make(message: String, duration: Duration, view: UIView? = nil) -> Self? {
        if let view = view {
            return Self.make(in: view, message: message, duration: duration)
        } else {
            guard let vc = getTopViewController() else { return nil }
            return Self.make(in: vc.view, message: message, duration: duration)
        }
    }

    public static func make(message: String, duration: Duration, view: UIView? = nil, action: String, completion: @escaping () -> Void) -> Self? {
        if let view = view {
            return Self.make(in: view, message: message, duration: .lengthLong).setAction(with: action, action: completion) as? Self
        } else {
            guard let vc = getTopViewController() else { return nil }
            return Self.make(in: vc.view, message: message, duration: .lengthLong).setAction(with: action, action: completion) as? Self
        }
    }
}
