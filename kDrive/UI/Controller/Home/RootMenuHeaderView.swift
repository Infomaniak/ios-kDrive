/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class RootMenuHeaderView: UICollectionReusableView {
    static let kind: UICollectionView.UICollectionViewSupplementaryViewKind = .custom("menuHeader")

    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploadable

    @IBOutlet var topConstraint: NSLayoutConstraint!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!

    @IBOutlet var offlineView: UIView!

    private weak var collectionView: UICollectionView?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        offlineView.isHidden = true
        hideIfNeeded()
    }

    func configureInCollectionView(
        _ collectionView: UICollectionView,
        driveFileManager _: DriveFileManager,
        presenter _: UIViewController
    ) {
        self.collectionView = collectionView
        observeNetworkChange()
    }

    private func hideIfNeeded() {
        if offlineView.isHidden {
            topConstraint.constant = 0
            bottomConstraint.constant = 0
        } else {
            topConstraint.constant = 16
            bottomConstraint.constant = 16
        }
    }

    private func reloadHeader() {
        hideIfNeeded()

        guard let collectionView else { return }
        UIView.transition(with: collectionView, duration: 0.25, options: .transitionCrossDissolve) {
            let sectionHeaderContext = UICollectionViewLayoutInvalidationContext()
            sectionHeaderContext.invalidateSupplementaryElements(
                ofKind: RootMenuHeaderView.kind.rawValue,
                at: [IndexPath(item: 0, section: 0)]
            )
            collectionView.collectionViewLayout.invalidateLayout(with: sectionHeaderContext)
        }
    }

    private func observeNetworkChange() {
        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                offlineView.isHidden = status != .offline
                reloadHeader()
            }
        }
    }
}
