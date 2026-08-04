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

import kDriveCore
import Lottie
import UIKit

class InformationFloatingPanelViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var animationView: LottieAnimationView!
    @IBOutlet var animationViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var additionalInformationLabel: UILabel!
    @IBOutlet var copyStackView: UIStackView!
    @IBOutlet var copyTextField: UITextField!
    @IBOutlet var leftButton: UIButton!
    @IBOutlet var rightButton: UIButton!

    var cancelHandler: ((UIButton) -> Void)?
    var actionHandler: ((UIButton) -> Void)?

    var drive: Drive?

    override func viewDidLoad() {
        super.viewDidLoad()
        leftButton.titleLabel?.numberOfLines = 2
        leftButton.titleLabel?.textAlignment = .center
        rightButton.titleLabel?.numberOfLines = 2
        rightButton.titleLabel?.textAlignment = .center

        additionalSafeAreaInsets.top = UIConstants.Padding.standard
    }

    private func updateSheetDetent() {
        view.layoutIfNeeded()

        let targetSize = CGSize(
            width: view.bounds.width,
            height: UIView.layoutFittingCompressedSize.height
        )
        let contentHeight = view.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        let bottomSafeArea = view.window?.safeAreaInsets.bottom ?? 0
        let isPad = traitCollection.userInterfaceIdiom == .pad

        let customDetent = UISheetPresentationController.Detent.custom(
            identifier: .init("informationDetentHeight")
        ) { _ in
            isPad ? (contentHeight + UIConstants.Padding.mediumSmall) :
                (contentHeight - bottomSafeArea)
        }
        if let sheet = sheetPresentationController {
            sheet.detents = [customDetent]
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSheetDetent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animationView.play()
    }

    @IBAction func copyButtonPressed(_ sender: UIButton) {
        let items = [URL(string: copyTextField.text!)!]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        ac.popoverPresentationController?.sourceView = sender
        present(ac, animated: true)
    }

    @IBAction func leftButtonPressed(_ sender: UIButton) {
        if let cancelHandler {
            cancelHandler(sender)
        } else {
            dismiss(animated: true)
        }
    }

    @IBAction func rightButtonPressed(_ sender: UIButton) {
        actionHandler?(sender)
    }

    class func instantiate() -> InformationFloatingPanelViewController {
        return Storyboard.informationFloatingPanel
            .instantiateViewController(
                withIdentifier: "InformationFloatingPanelViewController"
            ) as! InformationFloatingPanelViewController
    }

    class func instantiateSheet(drive: Drive? = nil) -> UIViewController {
        let contentVC = instantiate()
        contentVC.drive = drive
        contentVC.modalPresentationStyle = .pageSheet
        contentVC.loadViewIfNeeded()
        contentVC.sheetPresentationController?.prefersEdgeAttachedInCompactHeight = true
        contentVC.sheetPresentationController?
            .widthFollowsPreferredContentSizeWhenEdgeAttached = true

        if let sheet = contentVC.sheetPresentationController {
            sheet.prefersGrabberVisible = true
        }
        return contentVC
    }
}
