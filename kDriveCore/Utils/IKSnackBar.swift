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

    private weak var snackBar: IKSnackBar?

    private weak var mainRollbackWindow: UIWindow?

    private init() {}

    func setupWindowAndRootVC() -> UIViewController {
        let entryViewController: UIViewController
        if entryWindow == nil {
            entryViewController = UIViewController()
            entryWindow = IKWindow(with: entryViewController)
            entryWindow.isHidden = false
            mainRollbackWindow = UIApplication.shared.keyWindow
            // Adjust insets based on presented view controller under
            if let topViewInsets = mainRollbackWindow?.rootViewController?.displayedViewController.view.safeAreaInsets {
                let safeAreaInsets = entryViewController.view.safeAreaInsets
                let insets = UIEdgeInsets(top: topViewInsets.top - safeAreaInsets.top, left: topViewInsets.left - safeAreaInsets.left, bottom: topViewInsets.bottom - safeAreaInsets.bottom, right: topViewInsets.right - safeAreaInsets.right)
                entryViewController.additionalSafeAreaInsets = insets
            }
        } else {
            entryViewController = rootViewController!
        }
        return entryViewController
    }

    func displaySnackBar(message: String, duration: IKSnackBar.Duration) -> IKSnackBar {
        // Remove old snackbar
        snackBar?.dismiss()
        // Create new snackbar
        let vc = setupWindowAndRootVC()
        let snackBar = IKSnackBar(contextView: vc.view, message: message, duration: duration)
        entryWindow.isHidden = false
        self.snackBar = snackBar
        return snackBar
    }

    func displayPendingEntryOrRollbackWindow() {
        if snackBar == nil {
            displayRollbackWindow()
        }
    }

    private func displayRollbackWindow() {
        if #available(iOS 13.0, *) {
            entryWindow.windowScene = nil
        }
        entryWindow = nil
        if let mainRollbackWindow = mainRollbackWindow {
            mainRollbackWindow.makeKeyAndVisible()
        } else {
            UIApplication.shared.keyWindow?.makeKeyAndVisible()
        }
    }
}

extension UIViewController {
    var displayedViewController: UIViewController {
        if let controller = self as? UINavigationController, let visibleViewController = controller.visibleViewController {
            return visibleViewController.displayedViewController
        } else if let controller = self as? UISplitViewController, let lastViewController = controller.viewControllers.last {
            return lastViewController.displayedViewController
        } else if let controller = self as? UITabBarController, let selectedViewController = controller.selectedViewController {
            return selectedViewController.displayedViewController
        } else if let controller = presentedViewController {
            return controller.displayedViewController
        } else {
            return self
        }
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

    public static func make(message: String, duration: Duration) -> Self? {
        return IKWindowProvider.shared.displaySnackBar(message: message, duration: duration) as? Self
    }

    public func setAction(_ action: Action) -> SnackBarPresentable {
        return setAction(with: action.title, action: action.action)
    }

    override public func removeFromSuperview() {
        super.removeFromSuperview()
        IKWindowProvider.shared.displayPendingEntryOrRollbackWindow()
    }
}
