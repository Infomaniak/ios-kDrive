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

import SnackBar
import UIKit

class IKWindow: UIWindow {
    init(with rootVC: UIViewController) {
        if #available(iOS 13.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                super.init(windowScene: scene)
            } else {
                super.init(frame: UIScreen.main.bounds)
            }
        } else {
            super.init(frame: UIScreen.main.bounds)
        }
        backgroundColor = .clear
        rootViewController = rootVC
        accessibilityViewIsModal = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let rootViewController = IKWindowProvider.shared.rootViewController,
           let view = rootViewController.view.subviews.first {
            return view.hitTest(point, with: event)
        }

        return nil
    }
}

public class IKWindowProvider {
    public static let shared = IKWindowProvider()

    var entryWindow: IKWindow!
    var rootViewController: UIViewController? {
        return entryWindow?.rootViewController
    }

    private init() {}

    func setupWindowAndRootVC() -> UIViewController {
        let entryViewController: UIViewController
        if entryWindow == nil {
            entryViewController = UIViewController()
            entryWindow = IKWindow(with: entryViewController)
            entryWindow.isHidden = false
        } else {
            entryViewController = rootViewController!
        }
        return entryViewController
    }
}

public class IKSnackBar: SnackBar {
    public struct Action {
        let title: String
        let action: () -> Void

        public init(title: String, action: @escaping () -> Void) {
            self.title = title
            self.action = action
        }
    }

    required init(contextView: UIView, message: String, duration: Duration) {
        super.init(contextView: contextView, message: message, duration: duration)
        addShadow(elevation: 6)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public var style: SnackBarStyle {
        let textStyle = TextStyle.subtitle2
        let buttonStyle = TextStyle.action
        var style = SnackBarStyle()
        style.padding = 24
        style.background = KDriveCoreAsset.backgroundCardViewColor.color
        style.textColor = textStyle.color
        style.font = textStyle.font
        style.actionTextColor = buttonStyle.color
        style.actionTextColorAlpha = 1
        style.actionFont = buttonStyle.font
        return style
    }

    private static func getTopViewController() -> UIViewController? {
        let windows = UIApplication.shared.windows
        let keyWindow = windows.count == 1 ? windows.first : windows.first(where: \.isKeyWindow)
        if let topController = keyWindow?.rootViewController {
            return getVisibleViewController(from: topController)
        } else {
            return nil
        }
    }

    private static func getVisibleViewController(from viewController: UIViewController) -> UIViewController {
        if let navigationController = viewController as? UINavigationController,
           let visibleController = navigationController.visibleViewController {
            return getVisibleViewController(from: visibleController)
        } else if let tabBarController = viewController as? UITabBarController,
                  let selectedTabController = tabBarController.selectedViewController {
            return getVisibleViewController(from: selectedTabController)
        } else {
            if let presentedViewController = viewController.presentedViewController {
                return getVisibleViewController(from: presentedViewController)
            } else {
                return viewController
            }
        }
    }

    public static func make(message: String, duration: Duration, view: UIView? = nil) -> Self? {
        if let view = view {
            return Self.make(in: view, message: message, duration: duration)
        } else {
            let vc = IKWindowProvider.shared.setupWindowAndRootVC()
            return Self.make(in: vc.view, message: message, duration: duration)
        }
    }

    public func setAction(_ action: Action) -> SnackBarPresentable {
        return setAction(with: action.title, action: action.action)
    }

    public override func removeFromSuperview() {
        super.removeFromSuperview()
        // Remove window
    }
}
