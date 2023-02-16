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
import Sentry
import InfomaniakDI
import RealmSwift

protocol BackgroundSessionManager: NSObject, URLSessionTaskDelegate {
    // MARK: - Type aliases

    associatedtype Task
    associatedtype CompletionHandler
    associatedtype Operation

    // MARK: - Attributes

    var backgroundCompletionHandler: (() -> Void)? { get set }
    var backgroundSession: URLSession! { get }
    var tasksCompletionHandler: [String: CompletionHandler] { get set }
    var progressObservers: [String: NSKeyValueObservation] { get set }
    var operations: [String: Operation] { get set }

    func reconnectBackgroundTasks()
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)
    func getCompletionHandler(for task: Task, session: URLSession) -> CompletionHandler?
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
    func uploadTask(with request: URLRequest,
                    fromFile fileURL: URL,
                    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask
}

extension URLSession: FileUploadSession {}

public final class BackgroundUploadSessionManager: NSObject, BackgroundSessionManager, URLSessionDataDelegate, FileUploadSession {
    @LazyInjectService var uploadQueue: UploadQueue

    public typealias Task = URLSessionUploadTask
    public typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    public typealias Operation = UploadOperation
    public typealias BackgroundCompletionHandler = () -> Void

    public var backgroundCompletionHandler: (() -> Void)?
    private var backgroundCompletionHandlers: [String: BackgroundCompletionHandler] = [:]

    private var managedSessions: [String: URLSession] = [:]
    var backgroundSession: URLSession!
    public var identifier: String {
        return backgroundSession.identifier
    }

    var tasksCompletionHandler: [String: CompletionHandler] = [:]
    var tasksData: [String: Data] = [:]
    var progressObservers: [String: NSKeyValueObservation] = [:]
    var operations = [String: Operation]()

    private var syncQueue = DispatchQueue(
        label: "\(Bundle.main.bundleIdentifier ?? "com.infomaniak.drive").BackgroundUploadSessionManager.syncqueue",
        attributes: .concurrent
    )

    override public init() {
        super.init()
        
        BackgroundSessionManagerLog("Starting up")
        backgroundSession = getSessionOrCreate(for: UploadQueue.backgroundIdentifier)
    }

    public func getSessionOrCreate(for identifier: String) -> URLSession {
        if let session = syncQueue.sync(execute: { managedSessions[identifier] }) {
            return session
        }

        let backgroundUrlSessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        backgroundUrlSessionConfiguration.sessionSendsLaunchEvents = true
        backgroundUrlSessionConfiguration.allowsCellularAccess = true
        backgroundUrlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        backgroundUrlSessionConfiguration.httpMaximumConnectionsPerHost = 4 // This limit is not really respected because we are using http/2
        backgroundUrlSessionConfiguration.timeoutIntervalForRequest = 60 * 2 // 2 minutes before timeout
        backgroundUrlSessionConfiguration.timeoutIntervalForResource = 60 * 60 * 24 * 1 // 1 day before giving up (chunk upload session not valid after a day)
        backgroundUrlSessionConfiguration.networkServiceType = .responsiveData
        let session = URLSession(configuration: backgroundUrlSessionConfiguration, delegate: self, delegateQueue: nil)
        syncQueue.async(flags: .barrier) { [weak self] in
            self?.managedSessions[identifier] = session
        }
        return session
    }

    public func handleEventsForBackgroundURLSession(identifier: String, completionHandler: @escaping BackgroundCompletionHandler) {
        _ = getSessionOrCreate(for: identifier)
        syncQueue.async(flags: .barrier) { [weak self] in
            self?.backgroundCompletionHandlers[identifier] = completionHandler
        }
    }

    public func reconnectBackgroundTasks() {
        // TODO: Cleanup, nothing observed now
        return
        
//        // UploadFiles not uploaded _and_ a uploadingSession is present
//        let uploadedFiles = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
//            .filter(NSPredicate(format: "uploadDate = nil AND uploadingSession != nil"))
//
//        // For all NSURLSessionDataTask ID linked to chunk uploading within an uploadingSession …
//        let uploadingFilesWithSession = uploadedFiles.compactMap(\.uploadingSession)
//        for session in uploadingFilesWithSession {
//            for chunkTask in session.chunkTasks {
//                if let sessionIdentifier = chunkTask.sessionIdentifier {
//                    // … we re-register progress
//                    /*
//                    let session = getSessionOrCreate(for: sessionIdentifier)
//                    session.getTasksWithCompletionHandler { [unowned self] _, uploadTasks, _ in
//                        self.handleReconnectedTasks(tasks: uploadTasks, for: session)
//                    }
//                     */
//                }
//            }
//        }
    }

//    private func handleReconnectedTasks(tasks: [URLSessionUploadTask], for session: URLSession) {
//        syncQueue.async(flags: .barrier) {
//            for task in tasks {
//                if let sessionUrl = task.originalRequest?.url?.absoluteString,
//                   // TODO: No longer observed
//                   let fileId = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
//                   .filter(NSPredicate(format: "uploadDate = nil AND sessionUrl = %@", sessionUrl)).first?.id {
//
//                    self.progressObservers[session.identifier(for: task)] = task.progress.observe(\.fractionCompleted, options: .new) { [fileId] _, value in
//                        guard let newValue = value.newValue else {
//                            return
//                        }
//                        self.uploadQueue.publishProgress(newValue, for: fileId)
//                    }
//                }
//            }
//        }
//    }

    public func rescheduleForBackground(task: URLSessionDataTask?, fileUrl: URL?) -> URLSessionUploadTask? {
        if let request = task?.originalRequest,
           let fileUrl = fileUrl {
            let task = backgroundSession.uploadTask(with: request, fromFile: fileUrl)
            task.resume()
            BackgroundSessionManagerLog("Rescheduled task \(request.url?.absoluteString ?? "")")
            return task
        } else {
            return nil
        }
    }
    
    /// Called on reschedulling BG tasks
    public func uploadTask(with request: URLRequest,
                           fromFile fileURL: URL,
                           completionHandler: @escaping CompletionHandler) -> Task {
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        syncQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.tasksCompletionHandler[self.backgroundSession.identifier(for: task)] = completionHandler
        }
        return task
    }

    // MARK: Delegate
    
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive data: Data) {
        let taskIdentifier = session.identifier(for: dataTask)
        syncQueue.async(flags: .barrier) { [weak self] in
            if self?.tasksData[taskIdentifier] != nil {
                self?.tasksData[taskIdentifier]!.append(data)
            } else {
                self?.tasksData[taskIdentifier] = data
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskIdentifier = session.identifier(for: task)
        if let task = task as? URLSessionUploadTask {
            let taskData = syncQueue.sync { tasksData[taskIdentifier] }
            getCompletionHandler(for: task, session: session)?(taskData, task.response, error)
        }
        syncQueue.async(flags: .barrier) { [weak self] in
            self?.progressObservers[taskIdentifier]?.invalidate()
            self?.progressObservers[taskIdentifier] = nil
            self?.tasksData[taskIdentifier] = nil
            self?.tasksCompletionHandler[taskIdentifier] = nil
        }
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        BackgroundSessionManagerLog("Session didBecomeInvalidWithError \(session.identifier) \(error?.localizedDescription ?? "")",
                                    level: .error)
        if let error = error {
            SentrySDK.capture(error: error) { scope in
                scope.setContext(value: [
                    "Session Id": session.identifier
                ], key: "Session")
            }
        } else {
            SentrySDK.capture(message: "URLSession didBecomeInvalid - No Error") { scope in
                scope.setContext(value: [
                    "Session Id": session.identifier
                ], key: "Session")
            }
        }
    }
    
    // MARK: -

    func getCompletionHandler(for task: Task, session: URLSession) -> CompletionHandler? {
        BackgroundSessionManagerLog("getCompletionHandler :\(session)")

        let taskIdentifier = session.identifier(for: task)
        if let completionHandler = syncQueue.sync(execute: { tasksCompletionHandler[taskIdentifier] }) {
            return completionHandler
        } else if let requestUrl = task.originalRequest?.url?.absoluteString,
                  requestUrl.isEmpty == false {
            
            /*let file = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
            .filter(NSPredicate(format: "uploadDate = nil AND sessionUrl = %@", sessionUrl)).first*/
            
            // TODO: test and optimise
            // Fetch the first upload file WHERE a chunk upload URL is matching
            let files = Array(DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
                .where {
                ($0.uploadDate == nil) && ($0.uploadingSession.uploadSession != nil)
            })
                .filter {
                let result = $0.uploadingSession?.chunkTasks.where { $0.requestUrl == requestUrl }
                return result?.count ?? 0 > 0
            }
            
            guard let file = files.first else {
                // TODO: check this out
                assertionFailure("Not able to find linked UploadingFile")
                return nil
            }
            
            var operation: Operation!
            syncQueue.sync(flags: .barrier) { [unowned self] in
                if let op = self.operations[requestUrl] {
                    operation = op
                } else {
                    operation = UploadOperation(file: file, task: task, urlSession: self)
                }
                
                self.tasksCompletionHandler[taskIdentifier] = operation.uploadCompletion
                self.operations[requestUrl] = operation
            }
            
            return operation.uploadCompletion
        } else {
            logMissingCompletionHandler(for: task, session: session)
            return nil
        }
    }

    private func logMissingCompletionHandler(for task: Task, session: URLSession) {
        var filename: String?
        var hasUploadDate = false

        if let sessionUrl = task.originalRequest?.url?.absoluteString,
           let file = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
           .filter(NSPredicate(format: "sessionUrl = %@", sessionUrl)).first {
            filename = file.name
            hasUploadDate = file.uploadDate != nil
        }

        BackgroundSessionManagerLog("No completion handler found for session \(session.identifier) task url \(task.originalRequest?.url?.absoluteString ?? "")",
                                    level: .error)
        SentrySDK.capture(message: "URLSession getCompletionHandler - No completion handler found") { scope in
            scope.setContext(value: [
                "Session Id": session.identifier,
                "Task url": task.originalRequest?.url?.absoluteString ?? "",
                "Task error": task.error?.localizedDescription ?? "",
                "Upload file": filename ?? "",
                "Has Upload Date": hasUploadDate
            ], key: "Session")
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let identifier = session.configuration.identifier else { return }

        let completionHandler = syncQueue.sync { backgroundCompletionHandlers[identifier] }
        DispatchQueue.main.async { [weak self] in
            completionHandler?()
            self?.syncQueue.async(flags: .barrier) {
                self?.backgroundCompletionHandlers[identifier] = nil
            }
        }
    }
}
