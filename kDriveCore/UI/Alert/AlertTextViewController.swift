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

import InfomaniakCoreUIKit
import UIKit

/// Alert with text content
public class AlertTextViewController: AlertViewController {
    /**
     Creates a new alert with text content.
     - Parameters:
        - title: Title of the alert view
        - message: Text of the alert view
        - action: Label of the action button
        - hasCancelButton: Show or hide the cancel button
        - destructive: If this is `true`, the action button becomes red
        - loading: If this is set as true, the action button will automatically be set to the loading state while the `handler` is called. In this case, `handler` has to be **synchronous**
        - handler: Closure to execute when the action button is tapped
        - cancelHandler: Closure to execute when the cancel button is tapped
     */
    public convenience init(title: String,
                            message: String,
                            action: String,
                            hasCancelButton: Bool = true,
                            cancelString: String? = nil,
                            destructive: Bool = false,
                            loading: Bool = false,
                            handler: (() async -> Void)?,
                            cancelHandler: (() -> Void)? = nil) {
        let attributedText = NSAttributedString(string: message)
        self.init(title: title,
                  message: attributedText,
                  action: action,
                  hasCancelButton: hasCancelButton,
                  cancelString: cancelString,
                  destructive: destructive,
                  loading: loading,
                  handler: handler,
                  cancelHandler: cancelHandler)
    }

    /**
     Creates a new alert with text content.
     - Parameters:
        - title: Title of the alert view
        - message: Text of the alert view
        - action: Label of the action button
        - hasCancelButton: Show or hide the cancel button
        - destructive: If this is `true`, the action button becomes red
        - loading: If this is set as true, the action button will automatically be set to the loading state while the `handler` is called. In this case, `handler` has to be **synchronous**
        - handler: Closure to execute when the action button is tapped
        - cancelHandler: Closure to execute when the cancel button is tapped
     */
    public init(title: String,
                message: NSAttributedString,
                action: String,
                hasCancelButton: Bool = true,
                cancelString: String? = nil,
                destructive: Bool = false,
                loading: Bool = false,
                handler: (() async -> Void)?,
                cancelHandler: (() -> Void)? = nil) {
        let label = IKLabel()
        label.attributedText = message
        label.numberOfLines = 0
        label.style = .body1
        label.sizeToFit()
        super.init(title: title,
                   action: action,
                   hasCancelButton: hasCancelButton,
                   cancelString: cancelString,
                   destructive: destructive,
                   loading: loading,
                   handler: handler,
                   cancelHandler: cancelHandler)
        contentView = label
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
