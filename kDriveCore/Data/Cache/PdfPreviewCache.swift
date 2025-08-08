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

import Foundation
import InfomaniakCore

public class PdfPreviewCache {
    public static let shared = PdfPreviewCache()
    private let pdfCacheDirectory: URL

    private init() {
        pdfCacheDirectory = DriveFileManager.constants.cacheDirectoryURL.appendingPathComponent("PdfPreviews", isDirectory: true)
        try? FileManager.default.createDirectory(
            atPath: pdfCacheDirectory.path,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func isLocalVersionOlderThanRemote(for file: File) -> Bool {
        do {
            if let modifiedDate = try FileManager.default
                .attributesOfItem(atPath: pdfPreviewUrl(for: file).path)[.modificationDate] as? Date {
                if modifiedDate >= file.revisedAt {
                    return false
                }
            }
            return true
        } catch {
            return true
        }
    }

    private func pdfPreviewUrl(for file: AbstractFile) -> URL {
        return pdfCacheDirectory
            .appendingPathComponent("\(file.driveId)")
            .appendingPathComponent("\(file.id)")
            .appendingPathExtension("pdf")
    }

    public func retrievePdf(forSafeFile safeFile: File,
                            driveFileManager: DriveFileManager,
                            downloadTaskCreated: @escaping (URLSessionDownloadTask) -> Void,
                            completion: @escaping (URL?, Error?) -> Void) {
        assert(safeFile.isFrozen || safeFile.realm == nil, "safeFile is expected to be frozen or detached")
        if isLocalVersionOlderThanRemote(for: safeFile) {
            if let publicShareProxy = driveFileManager.publicShareProxy {
                let urlRequest = URLRequest(url: Endpoint.download(file: safeFile, publicShareProxy: publicShareProxy, as: "pdf")
                    .url)
                retrievePdf(
                    for: safeFile,
                    urlRequest: urlRequest,
                    downloadTaskCreated: downloadTaskCreated,
                    completion: completion
                )
            } else {
                guard let token = driveFileManager.apiFetcher.currentToken else {
                    completion(nil, DriveError.unknownToken)
                    return
                }

                driveFileManager.apiFetcher.performAuthenticatedRequest(token: token) { token, _ in
                    guard let token else { return }
                    var urlRequest = URLRequest(url: Endpoint.download(file: safeFile, as: "pdf").url)
                    urlRequest.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
                    self.retrievePdf(
                        for: safeFile,
                        urlRequest: urlRequest,
                        downloadTaskCreated: downloadTaskCreated,
                        completion: completion
                    )
                }
            }
        } else {
            let pdfUrl = pdfPreviewUrl(for: safeFile)
            completion(pdfUrl, nil)
        }
    }

    private func retrievePdf(
        for file: AbstractFile,
        urlRequest: URLRequest,
        downloadTaskCreated: @escaping (URLSessionDownloadTask) -> Void,
        completion: @escaping (URL?, Error?) -> Void
    ) {
        let pdfUrl = pdfPreviewUrl(for: file)
        let task = URLSession.shared.downloadTask(with: urlRequest) { url, _, error in
            guard let url else {
                completion(nil, error ?? DriveError.unknownError)
                return
            }

            do {
                let driveCacheDirectory = self.pdfCacheDirectory.appendingPathComponent(
                    "\(file.driveId)",
                    isDirectory: true
                )
                if !FileManager.default.fileExists(atPath: driveCacheDirectory.path) {
                    try FileManager.default.createDirectory(
                        at: driveCacheDirectory,
                        withIntermediateDirectories: true
                    )
                }
                try FileManager.default.copyOrReplace(sourceUrl: url, destinationUrl: pdfUrl)
                completion(pdfUrl, nil)
            } catch {
                completion(nil, error)
            }
        }
        downloadTaskCreated(task)
        task.resume()
    }
}
