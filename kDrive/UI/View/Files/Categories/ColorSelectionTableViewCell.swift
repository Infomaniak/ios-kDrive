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

protocol ColorSelectionDelegate: AnyObject {
    func didSelectColor(_ color: String)
}

class ColorSelectionTableViewCell: UITableViewCell {
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var collectionViewHeightConstraint: NSLayoutConstraint!

    weak var delegate: ColorSelectionDelegate?

    private let colors = [
        CategoryColor(hex: "#1abc9c"),
        CategoryColor(hex: "#11806a"),
        CategoryColor(hex: "#2ecc71"),
        CategoryColor(hex: "#128040"),
        CategoryColor(hex: "#3498db"),
        CategoryColor(hex: "#206694"),

        CategoryColor(hex: "#9b59b6"),
        CategoryColor(hex: "#71368a"),
        CategoryColor(hex: "#e91e63"),
        CategoryColor(hex: "#ad1457"),
        CategoryColor(hex: "#f1c40f"),
        CategoryColor(hex: "#c27c0e"),

        CategoryColor(hex: "#c45911"),
        CategoryColor(hex: "#44546a"),
        CategoryColor(hex: "#e74c3c"),
        CategoryColor(hex: "#992d22"),
        CategoryColor(hex: "#9d00ff"),
        CategoryColor(hex: "#00b0f0"),

        CategoryColor(hex: "#be8f00"),
        CategoryColor(hex: "#0b4899"),
        CategoryColor(hex: "#009945"),
        CategoryColor(hex: "#2e77b5"),
        CategoryColor(hex: "#70ad47")
    ]

    struct CategoryColor {
        let hex: String

        var color: UIColor? {
            return UIColor(hex: hex)
        }
    }

    private var contentSizeObservation: NSKeyValueObservation?

    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.register(cellView: ColorSelectionCollectionViewCell.self)
        collectionView.dataSource = self
        collectionView.delegate = self
        // Observe content size to adjust table view cell height (need to call `cell.layoutIfNeeded()`)
        contentSizeObservation = collectionView.observe(\.contentSize) { [weak self] collectionView, _ in
            self?.collectionViewHeightConstraint.constant = collectionView.contentSize.height
            self?.layoutIfNeeded()
        }
    }

    func selectColor(_ color: String) {
        let selectedColorIndex = colors.firstIndex { $0.hex == color } ?? 0
        collectionView.selectItem(
            at: IndexPath(row: selectedColorIndex, section: 0),
            animated: true,
            scrollPosition: .init(rawValue: 0)
        )
    }

    deinit {
        contentSizeObservation?.invalidate()
    }
}

extension ColorSelectionTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colors.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: ColorSelectionCollectionViewCell.self, for: indexPath)
        let color = colors[indexPath.row]
        cell.backgroundColor = color.color
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let color = colors[indexPath.row]
        delegate?.didSelectColor(color.hex)
    }
}
