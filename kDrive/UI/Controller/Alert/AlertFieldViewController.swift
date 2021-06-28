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
import kDriveCore
import MaterialOutlinedTextField

/// Alert with text field
class AlertFieldViewController: AlertViewController, UITextFieldDelegate {

    struct TextFieldConfiguration {
        var autocapitalizationType: UITextAutocapitalizationType = .sentences
        var autocorrectionType: UITextAutocorrectionType = .default
        var spellCheckingType: UITextSpellCheckingType = .default
        var keyboardType: UIKeyboardType = .default
        var keyboardAppearance: UIKeyboardAppearance = .default
        var returnKeyType: UIReturnKeyType = .default

        var selectedRange: Range<String.Index>?

        func apply(to textField: UITextField) {
            textField.autocapitalizationType = autocapitalizationType
            textField.autocorrectionType = autocorrectionType
            textField.spellCheckingType = spellCheckingType
            textField.keyboardType = keyboardType
            textField.keyboardAppearance = keyboardAppearance
            textField.returnKeyType = returnKeyType
        }

        func selectText(in textField: UITextField) {
            if let selectedRange = selectedRange,
                let str = textField.text,
                let startPosition = textField.position(from: textField.beginningOfDocument, offset: selectedRange.lowerBound.utf16Offset(in: str)),
                let endPosition = textField.position(from: textField.beginningOfDocument, offset: selectedRange.upperBound.utf16Offset(in: str)) {
                textField.selectedTextRange = textField.textRange(from: startPosition, to: endPosition)
            }
        }

        static let defaultConfiguration = TextFieldConfiguration()
        static let fileNameConfiguration = TextFieldConfiguration(autocapitalizationType: .none, autocorrectionType: .no, spellCheckingType: .no)
    }

    private let labelText: String?
    private let placeholder: String?
    private let text: String?
    private let handler: ((String) -> Void)?

    var textField: MaterialOutlinedTextField!
    var textFieldConfiguration: TextFieldConfiguration = .defaultConfiguration {
        didSet {
            if textField != nil {
                textFieldConfiguration.apply(to: textField)
            }
        }
    }
    var leadingConstraint: NSLayoutConstraint!

    /**
     Creates a new alert with text field.
     - Parameters:
        - title: Title of the alert view
        - placeholder: Placeholder of the text field
        - text: Text of the text field
        - action: Label of the action button
        - loading: If this is set as true, the action button will automatically be set to the loading state while the `handler` is called. In this case, `handler` has to be **synchronous**
        - handler: Closure to execute when the action button is tapped
     */
    convenience init(title: String, placeholder: String?, text: String? = nil, action: String, loading: Bool = false, handler: ((String) -> Void)?, cancelHandler: (() -> Void)? = nil) {
        self.init(title: title, label: placeholder, placeholder: placeholder, text: text, action: action, loading: loading, handler: handler, cancelHandler: cancelHandler)
    }

    /**
     Creates a new alert with text field.
     - Parameters:
        - title: Title of the alert view
        - label: Text of the text field label
        - placeholder: Placeholder of the text field
        - text: Text of the text field
        - action: Label of the action button
        - loading: If this is set as true, the action button will automatically be set to the loading state while the `handler` is called. In this case, `handler` has to be **synchronous**
        - handler: Closure to execute when the action button is tapped
     */
    init(title: String, label: String?, placeholder: String?, text: String? = nil, action: String, loading: Bool = false, handler: ((String) -> Void)?, cancelHandler: (() -> Void)? = nil) {
        self.labelText = label
        self.placeholder = placeholder
        self.text = text
        self.handler = handler
        super.init(title: title, action: action, loading: loading, handler: nil, cancelHandler: cancelHandler)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
        textFieldConfiguration.selectText(in: textField)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Observe keyboard
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        // Text field
        textField = MaterialOutlinedTextField()
        textField.label.text = labelText
        textField.placeholder = placeholder
        textField.text = text
        textField.setInfomaniakColors()
        textField.delegate = self
        textFieldConfiguration.apply(to: textField)
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)

        actionButton.isEnabled = !(text?.isEmpty ?? true)

        // Constraints
        leadingConstraint = textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        leadingConstraint.isActive = true
        let constraints = [
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            textField.topAnchor.constraint(equalTo: contentView.topAnchor),
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - Actions

    @objc override func action() {
        guard let name = textField.text else {
            return
        }

        if loading {
            setLoading(true)
            DispatchQueue.global(qos: .userInitiated).async {
                self.handler?(name)
                DispatchQueue.main.async {
                    self.setLoading(false)
                    self.dismiss(animated: true)
                }
            }
        } else {
            handler?(name)
            dismiss(animated: true)
        }
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let diff = alertView.frame.maxY - (UIScreen.main.bounds.height - keyboardFrame.cgRectValue.height)
            if diff > 0 {
                centerConstraint.constant = -(diff + 10)
                UIView.animate(withDuration: 0.2) {
                    self.view.layoutIfNeeded()
                }
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        centerConstraint.constant = 0
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }

    @objc func textFieldDidChange() {
        actionButton.isEnabled = !(textField.text?.isEmpty ?? true)
    }

    // MARK: - Text field delegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
    }

}
