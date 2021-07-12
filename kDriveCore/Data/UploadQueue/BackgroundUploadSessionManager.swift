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
import Foundation

protocol BackgroundSessionManager: NSObject, URLSessionTaskDelegate {
    // MARK: - Type aliases

    associatedtype Task
    associatedtype CompletionHandler
    associatedtype Operation

    // MARK: - Attributes

    static var instance: Self { get }

    var backgroundCompletionHandler: (() -> Void)? { get set }
    var backgroundTaskCount: Int { get }

    var backgroundSession: URLSession! { get }
    var tasksCompletionHandler: [Int: CompletionHandler] { get set }
    var progressObservers: [Int: NSKeyValueObservation] { get set }
    var operations: [Operation] { get set }

    func reconnectBackgroundTasks()
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)
    func getCompletionHandler(for task: Task) -> CompletionHandler?
}

extension BackgroundSessionManager {
    public var backgroundTaskCount: Int {
        return operations.count
    }
}

public protocol FileUploadSession {
    func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask
}

extension URLSession: FileUploadSession {}

public final class BackgroundUploadSessionManager: NSObject, BackgroundSessionManager, URLSessionDataDelegate, FileUploadSession {
    public typealias Task = URLSessionUploadTask
    public typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    public typealias Operation = UploadOperation

    public static let instance = BackgroundUploadSessionManager()

    public var backgroundCompletionHandler: (() -> Void)?

    static let maxBackgroundTasks = 10

    var backgroundSession: URLSession!
    var tasksCompletionHandler: [Int: CompletionHandler] = [:]
    var tasksData: [Int: Data] = [:]
    var progressObservers: [Int: NSKeyValueObservation] = [:]
    var operations = [Operation]()

    override private init() {
        super.init()
        let backgroundUrlSessionConfiguration = URLSessionConfiguration.background(withIdentifier: UploadQueue.backgroundIdentifier)
        backgroundUrlSessionConfiguration.sessionSendsLaunchEvents = true
        backgroundUrlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = true
        backgroundUrlSessionConfiguration.allowsCellularAccess = true
        backgroundUrlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        backgroundUrlSessionConfiguration.httpMaximumConnectionsPerHost = 4 // This limit is not really respected because we are using http/2
        backgroundUrlSessionConfiguration.timeoutIntervalForRequest = 60 * 2 // 2 minutes before timeout
        backgroundUrlSessionConfiguration.timeoutIntervalForResource = 60 * 60 * 24 * 3 // 3 days before giving up
        backgroundUrlSessionConfiguration.networkServiceType = .default
        backgroundSession = URLSession(configuration: backgroundUrlSessionConfiguration, delegate: self, delegateQueue: nil)
    }

    public func reconnectBackgroundTasks() {
        backgroundSession.getTasksWithCompletionHandler { _, uploadTasks, _ in
            for task in uploadTasks {
                if let sessionUrl = task.originalRequest?.url?.absoluteString,
                   let fileId = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
                   .filter(NSPredicate(format: "uploadDate = nil AND sessionUrl = %@", sessionUrl)).first?.id {
                    self.progressObservers[task.taskIdentifier] = task.progress.observe(\.fractionCompleted, options: .new) { [fileId = fileId] _, value in
                        guard let newValue = value.newValue else {
                            return
                        }
                        UploadQueue.instance.publishProgress(newValue, for: fileId)
                    }
                }
            }
        }
    }

    public func rescheduleForBackground(task: URLSessionDataTask?, fileUrl: URL?) -> Bool {
        if backgroundTaskCount < BackgroundUploadSessionManager.maxBackgroundTasks,
           let request = task?.originalRequest,
           let fileUrl = fileUrl {
            let task = backgroundSession.uploadTask(with: request, fromFile: fileUrl)
            task.resume()
            DDLogInfo("[BackgroundUploadSession] Rescheduled task \(request.url?.absoluteString ?? "")")
            return true
        } else {
            return false
        }
    }

    public func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping CompletionHandler) -> Task {
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        tasksCompletionHandler[task.taskIdentifier] = completionHandler
        return task
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if tasksData[dataTask.taskIdentifier] != nil {
            tasksData[dataTask.taskIdentifier]!.append(data)
        } else {
            tasksData[dataTask.taskIdentifier] = data
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let task = task as? URLSessionUploadTask {
            getCompletionHandler(for: task)?(tasksData[task.taskIdentifier], task.response, error)
        }
        progressObservers[task.taskIdentifier]?.invalidate()
        progressObservers[task.taskIdentifier] = nil
        tasksData[task.taskIdentifier] = nil
        tasksCompletionHandler[task.taskIdentifier] = nil
    }

    func getCompletionHandler(for task: Task) -> CompletionHandler? {
        if let completionHandler = tasksCompletionHandler[task.taskIdentifier] {
            return completionHandler
        } else if let sessionUrl = task.originalRequest?.url?.absoluteString,
                  let file = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
                  .filter(NSPredicate(format: "uploadDate = nil AND sessionUrl = %@", sessionUrl)).first {
            let operation = UploadOperation(file: file, task: task, urlSession: self)
            tasksCompletionHandler[task.taskIdentifier] = operation.uploadCompletion
            operations.append(operation)
            return operation.uploadCompletion
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
