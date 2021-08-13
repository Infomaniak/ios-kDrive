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

import CocoaLumberjackSwift
import FileProvider
import Foundation

public class DownloadArchiveOperation: Operation {
    // MARK: - Attributes

    private let archiveId: String
    private let driveFileManager: DriveFileManager
    private let urlSession: FileDownloadSession
    private var progressObservation: NSKeyValueObservation?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    public var task: URLSessionDownloadTask?
    public var error: DriveError?
    public var archiveUrl: URL?

    private var _executing = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _finished = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }

    override public var isExecuting: Bool {
        return _executing
    }

    override public var isFinished: Bool {
        return _finished
    }

    override public var isAsynchronous: Bool {
        return true
    }

    public init(archiveId: String, driveFileManager: DriveFileManager, urlSession: FileDownloadSession) {
        self.archiveId = archiveId
        self.driveFileManager = driveFileManager
        self.urlSession = urlSession
    }

    // MARK: - Public methods

    override public func start() {
        assert(!isExecuting, "Operation is already started")

        // Always check for cancellation before launching the task
        if isCancelled {
            // Must move the operation to the finished state if it is canceled.
            end(sessionUrl: nil)
            return
        }

        if !Constants.isInExtension {
            backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "File Archive Downloader") {
                DownloadQueue.instance.suspendAllOperations()
                // We don't support task rescheduling for archive download
                self.task?.cancel()
                self.end(sessionUrl: self.task?.originalRequest?.url)
            }
        }

        // If the operation is not canceled, begin executing the task
        _executing = true
        main()
    }

    override public func main() {
        DDLogInfo("[DownloadOperation] Downloading Archive of files \(archiveId) with session \(urlSession.identifier)")

        let url = URL(string: ApiRoutes.downloadArchive(driveId: driveFileManager.drive.id, archiveId: archiveId))!

        if let userToken = AccountManager.instance.getTokenForUserId(driveFileManager.drive.userId) {
            driveFileManager.apiFetcher.performAuthenticatedRequest(token: userToken) { [self] token, _ in
                if let token = token {
                    var request = URLRequest(url: url)
                    request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
                    task = urlSession.downloadTask(with: request, completionHandler: downloadCompletion)
                    progressObservation = task?.progress.observe(\.fractionCompleted, options: .new) { _, value in
                        guard let newValue = value.newValue else {
                            return
                        }
                        DownloadQueue.instance.publishProgress(newValue, for: archiveId)
                    }
                    task?.resume()
                } else {
                    self.error = .localError // Other error?
                    end(sessionUrl: url)
                }
            }
        } else {
            error = .localError // Other error?
            end(sessionUrl: url)
        }
    }

    func downloadCompletion(url: URL?, response: URLResponse?, error: Error?) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        if let error = error {
            // Client-side error
            DDLogError("[DownloadOperation] Client-side error for \(archiveId): \(error)")
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
                // We return because we don't want end() to be called as it is already called in the expiration handler
                return
            } else {
                self.error = .networkError
            }
        } else if let url = url {
            // Success
            DDLogInfo("[DownloadOperation] Download of \(archiveId) successful")
            do {
                let temporaryUrl = FileManager.default.temporaryDirectory.appendingPathComponent("\(archiveId)", isDirectory: true).appendingPathExtension("zip")

                if FileManager.default.fileExists(atPath: temporaryUrl.path) {
                    try? FileManager.default.removeItem(at: temporaryUrl)
                }
                try FileManager.default.createDirectory(at: temporaryUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: url, to: temporaryUrl)
                archiveUrl = temporaryUrl
            } catch {
                DDLogError("[DownloadOperation] Error moving file \(archiveId): \(error)")
                self.error = .localError
            }
        } else {
            // Server-side error
            DDLogError("[DownloadOperation] Server error for \(archiveId) (code: \(statusCode))")
            self.error = .serverError
        }
        end(sessionUrl: task?.originalRequest?.url)
    }

    override public func cancel() {
        super.cancel()
        task?.cancel()
    }

    private func end(sessionUrl: URL?) {
        DDLogInfo("[DownloadOperation] Download of archive \(archiveId) ended")

        progressObservation?.invalidate()
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }

        _executing = false
        _finished = true
    }
}
