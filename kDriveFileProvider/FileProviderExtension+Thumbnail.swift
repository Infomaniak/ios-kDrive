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

import FileProvider
import kDriveCore

extension FileProviderExtension {
    override func fetchThumbnails(
        for itemIdentifiers: [NSFileProviderItemIdentifier],
        requestedSize size: CGSize,
        perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, Error?) -> Void,
        completionHandler: @escaping (Error?) -> Void
    ) -> Progress {
        FileProviderLog("fetchThumbnails")
        let urlSession = URLSession(configuration: URLSessionConfiguration.default)
        let progress = Progress(totalUnitCount: Int64(itemIdentifiers.count))

        for identifier in itemIdentifiers {
            if let fileId = identifier.toFileId(),
               let file = driveFileManager.getCachedFile(id: fileId),
               let token = driveFileManager.apiFetcher.currentToken {
                var request = URLRequest(url: file.thumbnailURL)
                request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")

                // Download the thumbnail to disk
                // For simplicity, this sample downloads each thumbnail separately;
                // however, if possible, you should batch download all the thumbnails at once.
                let downloadTask = urlSession.downloadTask(with: request) { tempURL, _, error in

                    guard progress.isCancelled != true else {
                        return
                    }

                    var myErrorOrNil = error
                    var mappedDataOrNil: Data?

                    // If the download succeeds, map a data object to the file
                    if let fileURL = tempURL {
                        do {
                            mappedDataOrNil = try Data(contentsOf: fileURL, options: .alwaysMapped)
                        } catch let mappingError {
                            myErrorOrNil = mappingError
                        }
                    }

                    // Call the per thumbnail completion handler for each thumbnail requested.
                    perThumbnailCompletionHandler(identifier, mappedDataOrNil, myErrorOrNil)

                    DispatchQueue.main.async {
                        if progress.isFinished {
                            // Call this completion handler once all thumbnails are complete
                            completionHandler(nil)
                        }
                    }
                }

                // Add the download task's progress as a child to the overall progress.
                progress.addChild(downloadTask.progress, withPendingUnitCount: 1)

                // Start the download task.
                downloadTask.resume()
            } else {
                perThumbnailCompletionHandler(identifier, nil, nsError(code: .noSuchItem))
                progress.completedUnitCount += 1
                if progress.isFinished {
                    completionHandler(nil)
                }
            }
        }

        return progress
    }
}
