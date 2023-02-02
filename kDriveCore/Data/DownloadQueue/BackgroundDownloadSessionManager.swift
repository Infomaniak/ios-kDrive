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

import InfomaniakDI
import CocoaLumberjackSwift
import Foundation

public protocol FileDownloadSession: BackgroundSession {
    func downloadTask(with request: URLRequest, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask
}

extension URLSession: FileDownloadSession {}

public final class BackgroundDownloadSessionManager: NSObject, BackgroundSessionManager, URLSessionDownloadDelegate, FileDownloadSession {
    
    @InjectService var accountManager: AccountManageable
    
    public var identifier: String {
        return backgroundSession.identifier
    }

    public typealias Task = URLSessionDownloadTask
    public typealias CompletionHandler = (URL?, URLResponse?, Error?) -> Void
    public typealias Operation = DownloadOperation

    public static let instance = BackgroundDownloadSessionManager()

    public var backgroundCompletionHandler: (() -> Void)?

    static let maxBackgroundTasks = 10

    var backgroundSession: URLSession!
    var tasksCompletionHandler: [String: CompletionHandler] = [:]
    var progressObservers: [String: NSKeyValueObservation] = [:]
    var operations = [Operation]()

    override private init() {
        super.init()
        let backgroundUrlSessionConfiguration = URLSessionConfiguration.background(withIdentifier: DownloadQueue.backgroundIdentifier)
        backgroundUrlSessionConfiguration.sessionSendsLaunchEvents = true
        backgroundUrlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = true
        backgroundUrlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        backgroundUrlSessionConfiguration.networkServiceType = .responsiveData
        backgroundSession = URLSession(configuration: backgroundUrlSessionConfiguration, delegate: self, delegateQueue: nil)
    }

    public func reconnectBackgroundTasks() {
        backgroundSession.getTasksWithCompletionHandler { _, uploadTasks, _ in
            let realm = DriveFileManager.constants.uploadsRealm
            for task in uploadTasks {
                if let sessionUrl = task.originalRequest?.url?.absoluteString,
                   let fileId = realm.objects(DownloadTask.self).filter(NSPredicate(format: "sessionUrl = %@", sessionUrl)).first?.fileId {
                    self.progressObservers[self.backgroundSession.identifier(for: task)] = task.progress.observe(\.fractionCompleted, options: .new) { [fileId] _, value in
                        guard let newValue = value.newValue else {
                            return
                        }
                        DownloadQueue.instance.publishProgress(newValue, for: fileId)
                    }
                }
            }
        }
    }

    public func rescheduleForBackground(task: URLSessionDownloadTask?) -> String? {
        let syncLock = DispatchGroup()
        if backgroundTaskCount < BackgroundUploadSessionManager.maxBackgroundTasks,
           let request = task?.originalRequest {
            var sessionIdentifier: String?
            syncLock.enter()
            task?.cancel { data in
                let rescheduledTask: URLSessionDownloadTask
                if let data = data {
                    DDLogInfo("[BackgroundUploadSession] Rescheduled task \(request.url?.absoluteString ?? "") with resume data")
                    rescheduledTask = self.backgroundSession.downloadTask(withResumeData: data)
                } else {
                    DDLogInfo("[BackgroundUploadSession] Rescheduled task \(request.url?.absoluteString ?? "")")
                    rescheduledTask = self.backgroundSession.downloadTask(with: request)
                }
                rescheduledTask.resume()
                sessionIdentifier = self.backgroundSession.identifier
                syncLock.leave()
            }

            syncLock.wait()
            return sessionIdentifier
        } else {
            return nil
        }
    }

    public func downloadTask(with request: URLRequest, completionHandler: @escaping CompletionHandler) -> Task {
        let task = backgroundSession.downloadTask(with: request)
        tasksCompletionHandler[backgroundSession.identifier(for: task)] = completionHandler
        return task
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskIdentifier = session.identifier(for: task)
        // Unsuccessful completion
        if let task = task as? URLSessionDownloadTask {
            getCompletionHandler(for: task, session: session)?(nil, task.response, error)
        }
        progressObservers[taskIdentifier]?.invalidate()
        progressObservers[taskIdentifier] = nil
        tasksCompletionHandler[taskIdentifier] = nil
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Successful completion
        let taskIdentifier = session.identifier(for: downloadTask)
        getCompletionHandler(for: downloadTask, session: session)?(location, downloadTask.response, nil)
        progressObservers[taskIdentifier]?.invalidate()
        progressObservers[taskIdentifier] = nil
        tasksCompletionHandler[taskIdentifier] = nil
    }

    func getCompletionHandler(for task: Task, session: URLSession) -> CompletionHandler? {
        let taskIdentifier = session.identifier(for: task)
        if let completionHandler = tasksCompletionHandler[taskIdentifier] {
            return completionHandler
        } else if let sessionUrl = task.originalRequest?.url?.absoluteString,
                  let downloadTask = DriveFileManager.constants.uploadsRealm.objects(DownloadTask.self)
                  .filter(NSPredicate(format: "sessionUrl = %@", sessionUrl)).first,
                  let driveFileManager = accountManager.getDriveFileManager(for: downloadTask.driveId, userId: downloadTask.userId),
                  let file = driveFileManager.getCachedFile(id: downloadTask.fileId) {
            let operation = DownloadOperation(file: file, driveFileManager: driveFileManager, task: task, urlSession: self)
            tasksCompletionHandler[taskIdentifier] = operation.downloadCompletion
            operations.append(operation)
            return operation.downloadCompletion
        } else {
            return nil
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
