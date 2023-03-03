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
import InfomaniakDI
import RealmSwift
import Sentry

/// A completion handler to call to terminate processing a network request
public typealias RequestCompletionHandler = (Data?, URLResponse?, Error?) -> Void

/// A completion handler to call to terminate the handling of a background task finishing
public typealias BackgroundCompletionHandler = () -> Void

protocol BackgroundUploadSessionManageable: URLSessionTaskDelegate, URLSessionDelegate, URLSessionDataDelegate {
    /// Returns the background session
    var backgroundSession: URLSession! { get }

    /// Recreate the URLSessions from existing identifiers in base, and set this instance as delegate.
    func reconnectBackgroundTasks()

    func scheduled(task: URLSessionDataTask?, fileUrl: URL?)
    
    /// Cancel a running request, reschedule it on the background session, and returns a dedicated identifier
    /// - Parameters:
    ///   - task: The task to reschedule
    ///   - fileUrl: The url of the file to upload
    /// - Returns: a dedicated request identifier, or nil if failed
    func rescheduleForBackground(task: URLSessionDataTask, fileUrl: URL) -> String?
}

/// Something that can provide a completion handler for a request
protocol BackgroundUploadSessionCompletionable {
    /// Fetch completion handler for a specified request
    func getCompletionHandler(for task: URLSessionUploadTask, session: URLSession) -> RequestCompletionHandler?

}

public protocol Identifiable {
    var identifier: String { get }
}

extension URLSession: Identifiable {
    
    static let foregroundSessionIdentifier = "foreground"
    
    public var identifier: String {
        return configuration.identifier ?? Self.foregroundSessionIdentifier
    }

    public func identifier(for task: URLSessionTask) -> String {
        return "\(identifier)-\(task.taskIdentifier)"
    }
}

public final class BackgroundUploadSessionManager: NSObject,
                                                    BackgroundUploadSessionManageable,
                                                    BackgroundUploadSessionCompletionable {
    @LazyInjectService var uploadQueue: UploadQueue

    private var backgroundCompletionHandlers: [String: BackgroundCompletionHandler] = [:]

    var backgroundSession: URLSession!
    
    /// Running Upload Tasks
    private var managedTasks = [String: URLSessionUploadTask]()
    
    /// Existing sessions
    private var managedSessions = [String: URLSession]()

    public var identifier: String {
        return backgroundSession.identifier
    }

    /// Something to concatenate data received from delegate methods
    var tasksData: [String: Data] = [:]

    private var syncQueue = DispatchQueue(
        label: "\(Bundle.main.bundleIdentifier ?? "com.infomaniak.drive").BackgroundUploadSessionManager.syncqueue",
        attributes: .concurrent
    )

    override public init() {
        BackgroundSessionManagerLog("init")
        super.init()

        self.backgroundSession = getSessionOrCreate(for: UploadQueue.backgroundIdentifier)
    }

    public func getSessionOrCreate(for identifier: String) -> URLSession {
        BackgroundSessionManagerLog("getSessionOrCreate identifier:\(identifier)")
        if let session = syncQueue.sync(execute: { managedSessions[identifier] }) {
            BackgroundSessionManagerLog("fetched session:\(session)")
            return session
        }

        let backgroundUrlSessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        backgroundUrlSessionConfiguration.sessionSendsLaunchEvents = true
        backgroundUrlSessionConfiguration.allowsCellularAccess = true
        backgroundUrlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        backgroundUrlSessionConfiguration.httpMaximumConnectionsPerHost = 4 // This limit is not really respected because we are using http/2
        backgroundUrlSessionConfiguration.timeoutIntervalForRequest = 60 * 2 // 2 minutes before timeout
        backgroundUrlSessionConfiguration.timeoutIntervalForResource = 60 * 60 * 11 // 11h before giving up (chunk upload session not valid after)
        backgroundUrlSessionConfiguration.networkServiceType = .responsiveData
        let session = URLSession(configuration: backgroundUrlSessionConfiguration, delegate: self, delegateQueue: nil)
        syncQueue.async(flags: .barrier) { [unowned self] in
            BackgroundSessionManagerLog("store session:\(session) from identifier:\(identifier)")
            self.managedSessions[identifier] = session
        }

        BackgroundSessionManagerLog("generated session:\(session) from identifier:\(identifier)")
        return session
    }

    /// Entry point for app delegate
    public func handleEventsForBackgroundURLSession(identifier: String, completionHandler: @escaping BackgroundCompletionHandler) {
        BackgroundSessionManagerLog("handleEventsForBackgroundURLSession identifier:\(identifier)")
        #warning("disabled")
        return
        
        _ = getSessionOrCreate(for: identifier)
        syncQueue.async(flags: .barrier) { [unowned self] in
            self.backgroundCompletionHandlers[identifier] = completionHandler
        }
    }

    public func reconnectBackgroundTasks() {
        BackgroundSessionManagerLog("reconnectBackgroundTasks")
        #warning("disabled")
        return
        
        // Re-generate NSURLSession from identifiers
        /*let uploadingChunkTasks = DriveFileManager.constants.uploadsRealm.objects(UploadingChunkTask.self)
        let uniqueSessionIdentifiers = Set(uploadingChunkTasks.compactMap(\.sessionIdentifier))
        for sessionIdentifier in uniqueSessionIdentifiers {
            _ = getSessionOrCreate(for: sessionIdentifier)
        }*/
    }

    
    public func scheduled(task: URLSessionDataTask?, fileUrl: URL?) {
        BackgroundSessionManagerLog("scheduled task:\(task)")
        // TODO:
    }
    
    public func rescheduleForBackground(task: URLSessionDataTask, fileUrl: URL) -> String? {
        BackgroundSessionManagerLog("rescheduleForBackground task:\(task)")
        #warning("disabled")
        return nil
        
        if let request = task.originalRequest {
            let task = backgroundSession.uploadTask(with: request, fromFile: fileUrl)
            task.resume()
            
            let identifier = backgroundSession.identifier(for: task)
            BackgroundSessionManagerLog("Rescheduled identifier:\(identifier) task:\(request.url?.absoluteString ?? "")")
            
            return identifier
        } else {
            BackgroundSessionManagerLog("Rescheduled task failed task:\(task), fileUrl:\(fileUrl.path)", level: .error)
            return nil
        }
    }

    // MARK: - URLSessionDataDelegate

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive data: Data) {
        let taskIdentifier = session.identifier(for: dataTask)
        syncQueue.async(flags: .barrier) { [unowned self] in
            if var taskData = self.tasksData[taskIdentifier] {
                taskData.append(data)
                self.tasksData[taskIdentifier] = taskData
            } else {
                self.tasksData[taskIdentifier] = data
            }
        }
    }
    
    // MARK: - URLSessionDelegate

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        BackgroundSessionManagerLog("urlSession session:\(session) didCompleteWithError:\(error) identifier:\(session.identifier)")
        #warning("disabled")
        return
        
        let taskIdentifier = session.identifier(for: task)
        if let task = task as? URLSessionUploadTask {
            let taskData = syncQueue.sync { tasksData[taskIdentifier] }
            let completionHandler = getCompletionHandler(for: task, session: session)
            completionHandler?(taskData, task.response, error)
        }
        syncQueue.async(flags: .barrier) { [unowned self] in
            self.tasksData[taskIdentifier] = nil
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        BackgroundSessionManagerLog("urlSessionDidFinishEvents session:\(session) identifier:\(session.identifier)")
        #warning("disabled")
        return
        
        guard let identifier = session.configuration.identifier else { return }

        let completionHandler = syncQueue.sync { backgroundCompletionHandlers[identifier] }
        DispatchQueue.main.async { [unowned self] in
            completionHandler?()
            self.syncQueue.async(flags: .barrier) {
                self.backgroundCompletionHandlers[identifier] = nil
            }
        }
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        BackgroundSessionManagerLog("Session didBecomeInvalidWithError \(session.identifier) \(error?.localizedDescription ?? "")",
                                    level: .error)
        #warning("disabled")
        return
        
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

    // MARK: - BackgroundUploadSessionCompletionable

    func getCompletionHandler(for task: URLSessionUploadTask, session: URLSession) -> RequestCompletionHandler? {
        BackgroundSessionManagerLog("getCompletionHandler :\(session)")
        #warning("disabled")
        return nil
        
        var tempFile: UploadFile?
        let taskIdentifier = session.identifier(for: task)
        if let requestUrl = task.originalRequest?.url?.absoluteString,
           requestUrl.isEmpty == false {
            BackgroundSessionManagerLog("completionHandler from URL:\(requestUrl) :\(session)")

            let files = Array(DriveFileManager.constants.uploadsRealm.objects(UploadFile.self))
            let matchingFile = files.firstContaining(chunkUrl: requestUrl)

            guard let matchedFile = matchingFile?.detached() else {
                logMissingCompletionHandler(for: task, session: session)
                return nil
            }

            tempFile = matchedFile

            BackgroundSessionManagerLog("completionHandler fid:\(tempFile?.id) :\(session)")
            var operation: UploadOperationable?
            syncQueue.sync(flags: .barrier) { [unowned self] in
                if let fetchedOperation = self.uploadQueue.getOperation(forFileId: matchedFile.id) {
                    BackgroundSessionManagerLog("found OP:\(fetchedOperation) in upload queue fid:\(matchedFile.id)")
                    operation = fetchedOperation
                } else if let newOP = self.uploadQueue.saveToRealmAndAddtoQueue(file: matchedFile) {
                    BackgroundSessionManagerLog("added OP:\(newOP) in upload queue fid:\(matchedFile.id)")
                    newOP.restore(task: task, session: session)
                    operation = newOP
                }

                guard let operation else {
                    assertionFailure("expecting an operation, not nil")
                    return
                }
            }

            guard let operation else {
                logMissingCompletionHandler(for: task, session: session)
                return nil
            }

            return operation.uploadCompletion
        } else {
            logMissingCompletionHandler(for: task, session: session, file: tempFile)
            return nil
        }
    }

    private func logMissingCompletionHandler(for task: URLSessionUploadTask, session: URLSession, file: UploadFile? = nil) {
        BackgroundSessionManagerLog("logMissingCompletionHandler :\(task)")
        var filename: String?
        var hasUploadDate = false

        if let file {
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
}
