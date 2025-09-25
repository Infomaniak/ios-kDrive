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

import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

class RootMenuCell: UICollectionViewCell {
    static let identifier = String(describing: RootMenuCell.self)

    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = KDriveResourcesAsset.separatorColor.color
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentInsetView: UIView = {
        let view = UIView()
        view.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = KDriveResourcesAsset.iconColor.color
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = IKLabel()
        label.style = .subtitle2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let chevronImageView: UIImageView = {
        let imageView = UIImageView(image: KDriveResourcesAsset.chevronRight.image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = KDriveResourcesAsset.secondaryTextColor.color
        return imageView
    }()

    override var isSelected: Bool {
        didSet {
            contentInsetView.backgroundColor = isSelected ?
                KDriveResourcesAsset.itemSelectedBackgroundColor.color : InfomaniakCoreAsset
                .backgroundCardView.color
        }
    }

    override var isHighlighted: Bool {
        didSet {
            contentInsetView.backgroundColor = isHighlighted ?
                KDriveResourcesAsset.itemSelectedBackgroundColor.color : InfomaniakCoreAsset
                .backgroundCardView.color
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        focusEffect = nil
        contentView.addSubview(contentInsetView)
        contentInsetView.addSubview(iconImageView)
        contentInsetView.addSubview(titleLabel)
        contentInsetView.addSubview(chevronImageView)
        contentInsetView.addSubview(separatorView)

        topConstraint = contentInsetView.topAnchor.constraint(equalTo: contentView.topAnchor)
        bottomConstraint = contentInsetView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)

        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        NSLayoutConstraint.activate([
            separatorView.leadingAnchor.constraint(equalTo: contentInsetView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: contentInsetView.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentInsetView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),

            contentInsetView.heightAnchor.constraint(equalToConstant: 60),
            contentInsetView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            contentInsetView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            topConstraint!,
            bottomConstraint!,

            iconImageView.leadingAnchor.constraint(equalTo: contentInsetView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentInsetView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 26),
            iconImageView.heightAnchor.constraint(equalToConstant: 26),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentInsetView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: chevronImageView.trailingAnchor, constant: -12),

            chevronImageView.trailingAnchor.constraint(equalTo: contentInsetView.trailingAnchor, constant: -24),
            chevronImageView.centerYAnchor.constraint(equalTo: contentInsetView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    func configure(title: String, icon: UIImage?) {
        titleLabel.text = title
        iconImageView.image = icon
    }

    open func initWithPositionAndShadow(isFirst: Bool = false, isLast: Bool = false, elevation: Double = 0, radius: CGFloat = 6) {
        if isLast && isFirst {
            separatorView.isHidden = true
            topConstraint?.constant = 8
            bottomConstraint?.constant = 8
            contentInsetView.roundCorners(
                corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner],
                radius: radius
            )
        } else if isFirst {
            separatorView.isHidden = false
            topConstraint?.constant = 8
            bottomConstraint?.constant = 0
            contentInsetView.roundCorners(corners: [.layerMaxXMinYCorner, .layerMinXMinYCorner], radius: radius)
        } else if isLast {
            separatorView.isHidden = true
            topConstraint?.constant = 0
            bottomConstraint?.constant = 8
            contentInsetView.roundCorners(corners: [.layerMaxXMaxYCorner, .layerMinXMaxYCorner], radius: radius)
        } else {
            separatorView.isHidden = false
            topConstraint?.constant = 0
            bottomConstraint?.constant = 0
            contentInsetView.roundCorners(
                corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner],
                radius: 0
            )
        }
        contentInsetView.addShadow(elevation: elevation)
    }
}
