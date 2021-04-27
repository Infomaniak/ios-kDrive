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
import WebKit

class OfficePreviewCollectionViewCell: PreviewCollectionViewCell {

    @IBOutlet weak var documentPreview: WKWebView!

    override func awakeFromNib() {
        super.awakeFromNib()
        documentPreview.scrollView.showsVerticalScrollIndicator = false
        documentPreview.addShadow()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        documentPreview.load(URLRequest(url: URL(string: "about:blank")!))
    }

    override func configureWith(file: File) {
        documentPreview.loadFileURL(file.localUrl, allowingReadAccessTo: file.localUrl)
    }

}
