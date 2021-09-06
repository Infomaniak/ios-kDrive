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
    var tasksCompletionHandler: [String: CompletionHandler] { get set }
    var progressObservers: [String: NSKeyValueObservation] { get set }
    var operations: [Operation] { get set }

    func reconnectBackgroundTasks()
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)
    func getCompletionHandler(for task: Task, session: URLSession) -> CompletionHandler?
}

extension BackgroundSessionManager {
    public var backgroundTaskCount: Int {
        return operations.count
    }
}

public protocol BackgroundSession {
    var identifier: String { get }
}

extension URLSession: BackgroundSession {
    public var identifier: String {
        return configuration.identifier ?? "foreground"
    }

    public func identifier(for task: URLSessionTask) -> String {
        return "\(identifier)-\(task.taskIdentifier)"
    }
}

public protocol FileUploadSession: BackgroundSession {
    func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask
}

extension URLSession: FileUploadSession {}

public final class BackgroundUploadSessionManager: NSObject, BackgroundSessionManager, URLSessionDataDelegate, FileUploadSession {
    public typealias Task = URLSessionUploadTask
    public typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    public typealias Operation = UploadOperation
    public typealias BackgroundCompletionHandler = () -> Void

    public static let instance = BackgroundUploadSessionManager()

    public var backgroundCompletionHandler: (() -> Void)?
    private var backgroundCompletionHandlers: [String: BackgroundCompletionHandler] = [:]
    static let maxBackgroundTasks = 10

    private var managedSessions: [String: URLSession] = [:]
    var backgroundSession: URLSession!
    public var identifier: String {
        return backgroundSession.identifier
    }

    var tasksCompletionHandler: [String: CompletionHandler] = [:]
    var tasksData: [String: Data] = [:]
    var progressObservers: [String: NSKeyValueObservation] = [:]
    var operations = [Operation]()

    override private init() {
        super.init()
        backgroundSession = getSession(for: UploadQueue.backgroundIdentifier)
    }

    public func getSession(for identifier: String) -> URLSession {
        if let session = managedSessions[identifier] {
            return session
        }

        let backgroundUrlSessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        backgroundUrlSessionConfiguration.sessionSendsLaunchEvents = true
        backgroundUrlSessionConfiguration.allowsCellularAccess = true
        backgroundUrlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        backgroundUrlSessionConfiguration.httpMaximumConnectionsPerHost = 4 // This limit is not really respected because we are using http/2
        backgroundUrlSessionConfiguration.timeoutIntervalForRequest = 60 * 2 // 2 minutes before timeout
        backgroundUrlSessionConfiguration.timeoutIntervalForResource = 60 * 60 * 24 * 3 // 3 days before giving up
        backgroundUrlSessionConfiguration.networkServiceType = .responsiveData
        let session = URLSession(configuration: backgroundUrlSessionConfiguration, delegate: self, delegateQueue: nil)
        managedSessions[identifier] = session
        return session
    }

    public func handleEventsForBackgroundURLSession(identifier: String, completionHandler: @escaping BackgroundCompletionHandler) {
        _ = getSession(for: identifier)
        backgroundCompletionHandlers[identifier] = completionHandler
    }

    public func reconnectBackgroundTasks() {
        let uploadedFiles = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self).filter(NSPredicate(format: "uploadDate = nil AND sessionUrl != \"\""))
        let uniqueSessionIdentifiers = Set(uploadedFiles.compactMap(\.sessionId))
        for sessionIdentifier in uniqueSessionIdentifiers {
            let session = getSession(for: sessionIdentifier)
            session.getTasksWithCompletionHandler { _, uploadTasks, _ in
                for task in uploadTasks {
                    if let sessionUrl = task.originalRequest?.url?.absoluteString,
                       let fileId = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
                       .filter(NSPredicate(format: "uploadDate = nil AND sessionUrl = %@", sessionUrl)).first?.id {
                        self.progressObservers[session.identifier(for: task)] = task.progress.observe(\.fractionCompleted, options: .new) { [fileId = fileId] _, value in
                            guard let newValue = value.newValue else {
                                return
                            }
                            UploadQueue.instance.publishProgress(newValue, for: fileId)
                        }
                    }
                }
            }
        }
    }

    public func rescheduleForBackground(task: URLSessionDataTask?, fileUrl: URL?) -> String? {
        if backgroundTaskCount < BackgroundUploadSessionManager.maxBackgroundTasks,
           let request = task?.originalRequest,
           let fileUrl = fileUrl {
            let task = backgroundSession.uploadTask(with: request, fromFile: fileUrl)
            task.resume()
            DDLogInfo("[BackgroundUploadSession] Rescheduled task \(request.url?.absoluteString ?? "")")
            return backgroundSession.identifier
        } else {
            return nil
        }
    }

    public func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping CompletionHandler) -> Task {
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        tasksCompletionHandler[backgroundSession.identifier(for: task)] = completionHandler
        return task
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let taskIdentifier = session.identifier(for: dataTask)
        if tasksData[taskIdentifier] != nil {
            tasksData[taskIdentifier]!.append(data)
        } else {
            tasksData[taskIdentifier] = data
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskIdentifier = session.identifier(for: task)
        if let task = task as? URLSessionUploadTask {
            getCompletionHandler(for: task, session: session)?(tasksData[taskIdentifier], task.response, error)
        }
        progressObservers[taskIdentifier]?.invalidate()
        progressObservers[taskIdentifier] = nil
        tasksData[taskIdentifier] = nil
        tasksCompletionHandler[taskIdentifier] = nil
    }

    func getCompletionHandler(for task: Task, session: URLSession) -> CompletionHandler? {
        let taskIdentifier = session.identifier(for: task)
        if let completionHandler = tasksCompletionHandler[taskIdentifier] {
            return completionHandler
        } else if let sessionUrl = task.originalRequest?.url?.absoluteString,
                  let file = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
                  .filter(NSPredicate(format: "uploadDate = nil AND sessionUrl = %@", sessionUrl)).first {
            let operation = UploadOperation(file: file, task: task, urlSession: self)
            tasksCompletionHandler[taskIdentifier] = operation.uploadCompletion
            operations.append(operation)
            return operation.uploadCompletion
        } else {
            return nil
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let identifier = session.configuration.identifier else { return }

        DispatchQueue.main.async {
            self.backgroundCompletionHandlers[identifier]?()
            self.backgroundCompletionHandlers[identifier] = nil
        }
    }
}
