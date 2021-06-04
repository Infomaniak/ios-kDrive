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
import VisionKit
import kDriveCore

enum ScanFileFormat: Int, CaseIterable {
    case pdf, image

    var title: String {
        switch self {
        case .pdf:
            return "PDF"
        case .image:
            return "Image (.JPG)"
        }
    }

    var uti: UTI {
        switch self {
        case .pdf:
            return .pdf
        case .image:
            return .jpeg
        }
    }

    var `extension`: String {
        return uti.preferredFilenameExtension!
    }
}

enum PhotoFileFormat: Int, CaseIterable {
    case heic, jpg, png

    var title: String {
        switch self {
        case .heic:
            return "HEIF"
        case .jpg:
            return "JPG"
        case .png:
            return "PNG"
        }
    }

    var uti: UTI {
        switch self {
        case .heic:
            return .heic
        case .jpg:
            return .jpeg
        case .png:
            return .png
        }
    }

    var `extension`: String {
        return uti.preferredFilenameExtension!
    }
}

class ScanTypeTableViewCell: UITableViewCell {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    var didSelectIndex: ((Int) -> Void)?

    @IBAction func segmentedControlChanged(_ sender: UISegmentedControl) {
        didSelectIndex?(sender.selectedSegmentIndex)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        var size: CGFloat = 14
        if UIScreen.main.bounds.width < 390 {
            size = ceil(size * UIScreen.main.bounds.width / 390)
        }
        let font = UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: size))
        segmentedControl.setTitleTextAttributes([.foregroundColor: KDriveAsset.disconnectColor.color, .font: font], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: font], for: .selected)
    }

    func configureForPhoto() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.isEnabled = true
        for fileFormat in PhotoFileFormat.allCases {
            segmentedControl.setTitle(fileFormat.title, forSegmentAt: fileFormat.rawValue)
        }
    }

    @available(iOS 13.0, *)
    func configureWith(scan: VNDocumentCameraScan) {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.isEnabled = scan.pageCount == 1
        for fileFormat in ScanFileFormat.allCases {
            segmentedControl.setTitle(fileFormat.title, forSegmentAt: fileFormat.rawValue)
        }
    }

}
