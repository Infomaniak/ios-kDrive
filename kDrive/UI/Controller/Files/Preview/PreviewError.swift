/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

import Foundation

class PreviewError {
    let fileId: Int
    var downloadError: Error?

    init(fileId: Int, downloadError: Error?) {
        self.fileId = fileId
        self.downloadError = downloadError
    }
}

class OfficePreviewError: PreviewError {
    var pdfGenerationProgress: Progress?
    var downloadTask: URLSessionDownloadTask?
    var pdfUrl: URL?

    init(
        fileId: Int,
        pdfGenerationProgress: Progress? = nil,
        downloadTask: URLSessionDownloadTask? = nil,
        pdfUrl: URL? = nil,
        downloadError: Error? = nil
    ) {
        super.init(fileId: fileId, downloadError: downloadError)
        self.pdfGenerationProgress = pdfGenerationProgress
        self.downloadTask = downloadTask
        self.pdfUrl = pdfUrl
    }

    func addDownloadTask(_ downloadTask: URLSessionDownloadTask) {
        self.downloadTask = downloadTask
        pdfGenerationProgress?.completedUnitCount += 1
        pdfGenerationProgress?.addChild(downloadTask.progress, withPendingUnitCount: 9)
    }

    func removeDownloadTask() {
        pdfGenerationProgress = nil
        downloadTask = nil
    }
}
