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
import CocoaLumberjackSwift

public class DownloadOperation: Operation {

    // MARK: - Attributes

    private let file: File
    private let driveFileManager: DriveFileManager
    private let urlSession: FileDownloadSession
    private var task: URLSessionDownloadTask?
    private var progressObservation: NSKeyValueObservation?

    public var error: DriveError?

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

    public override var isExecuting: Bool {
        return _executing
    }

    public override var isFinished: Bool {
        return _finished
    }

    public override var isAsynchronous: Bool {
        return true
    }

    // MARK: - Public methods

    public init(file: File, driveFileManager: DriveFileManager, urlSession: FileDownloadSession) {
        self.file = File(value: file)
        self.driveFileManager = driveFileManager
        self.urlSession = urlSession
    }

    public init(file: File, driveFileManager: DriveFileManager, task: URLSessionDownloadTask, urlSession: FileDownloadSession) {
        self.file = file
        self.driveFileManager = driveFileManager
        self.urlSession = urlSession
        self.task = task
    }

    public override func start() {
        assert(!isExecuting, "Operation is already started")

        DDLogInfo("[DownloadOperation] Download of \(file.id) started")
        // Always check for cancellation before launching the task
        if isCancelled {
            DDLogInfo("[DownloadOperation] Download of \(file.id) canceled")
            // Must move the operation to the finished state if it is canceled.
            end()
            return
        }

        // If the operation is not canceled, begin executing the task
        _executing = true
        main()
    }

    public override func main() {
        DDLogInfo("[DownloadOperation] Downloading \(file.id)")

        let url = URL(string: ApiRoutes.downloadFile(file: file))!

        if let userToken = AccountManager.instance.getTokenForUserId(driveFileManager.drive.userId) {
            driveFileManager.apiFetcher.performAuthenticatedRequest(token: userToken) { [self] (token, error) in
                if let token = token {
                    var request = URLRequest(url: url)
                    request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
                    task = urlSession.downloadTask(with: request, completionHandler: downloadCompletion)
                    progressObservation = task?.progress.observe(\.fractionCompleted, options: .new, changeHandler: { [fileId = file.id] (progress, value) in
                        guard let newValue = value.newValue else {
                            return
                        }
                        DownloadQueue2.instance.publishProgress(newValue, for: fileId)
                    })
                    task?.resume()
                } else {
                    self.error = .localError // Other error?
                    end()
                }
            }
        } else {
            error = .localError // Other error?
            end()
        }
    }

    public override func cancel() {
        DDLogInfo("[DownloadOperation] Download of \(file.id) canceled")
        super.cancel()
        task?.cancel()
    }

    // MARK: - Private methods

    func downloadCompletion(url: URL?, response: URLResponse?, error: Error?) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        // TODO: Delete download task

        if let error = error {
            // Client-side error
            DDLogError("[DownloadOperation] Client-side error for \(file.id): \(error)")
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
                self.error = .taskCancelled
            } else {
                self.error = .networkError
            }
        } else if let url = url {
            // Success
            DDLogError("[DownloadOperation] Download of \(file.id) successful")
            do {
                if FileManager.default.fileExists(atPath: file.localUrl.path) {
                    try? FileManager.default.removeItem(at: file.localUrl)
                }
                try FileManager.default.createDirectory(at: file.localUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: url, to: file.localUrl)
                file.applyLastModifiedDateToLocalFile()
            } catch {
                DDLogError("[DownloadOperation] Error moving file \(file.id): \(error)")
                self.error = .localError
            }
        } else {
            // Server-side error
            DDLogError("[DownloadOperation] Server error for \(file.id) (code: \(statusCode))")
            self.error = .serverError
        }
        end()
    }

    private func end() {
        progressObservation?.invalidate()
        _executing = false
        _finished = true
    }
}
