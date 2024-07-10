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

public struct TextFieldConfiguration {
    public var autocapitalizationType: UITextAutocapitalizationType = .sentences
    public var autocorrectionType: UITextAutocorrectionType = .default
    public var spellCheckingType: UITextSpellCheckingType = .default
    public var keyboardType: UIKeyboardType = .default
    public var keyboardAppearance: UIKeyboardAppearance = .default
    public var returnKeyType: UIReturnKeyType = .default

    public var selectedRange: Range<String.Index>?

    public func apply(to textField: UITextField) {
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = autocorrectionType
        textField.spellCheckingType = spellCheckingType
        textField.keyboardType = keyboardType
        textField.keyboardAppearance = keyboardAppearance
        textField.returnKeyType = returnKeyType
    }

    public func selectText(in textField: UITextField) {
        if let selectedRange,
           let str = textField.text,
           let startPosition = textField.position(
               from: textField.beginningOfDocument,
               offset: selectedRange.lowerBound.utf16Offset(in: str)
           ),
           let endPosition = textField.position(
               from: textField.beginningOfDocument,
               offset: selectedRange.upperBound.utf16Offset(in: str)
           ) {
            textField.selectedTextRange = textField.textRange(from: startPosition, to: endPosition)
        }
    }

    public static let defaultConfiguration = TextFieldConfiguration()
    public static let fileNameConfiguration = TextFieldConfiguration(
        autocapitalizationType: .none,
        autocorrectionType: .no,
        spellCheckingType: .no
    )
    public static let fileExtensionConfiguration = TextFieldConfiguration(
        autocapitalizationType: .none,
        autocorrectionType: .no,
        spellCheckingType: .no
    )
}
