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

// periphery:ignore
protocol BackgroundUploadSessionManageable: URLSessionTaskDelegate, URLSessionDelegate, URLSessionDataDelegate {
    var backgroundSession: URLSession! { get }

    func reconnectBackgroundTasks()

    func scheduled(task: URLSessionDataTask?, fileUrl: URL?)

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
        Log.bgSessionManager("init")
        super.init()

        backgroundSession = getSessionOrCreate(for: UploadServiceBackgroundIdentifier.app)
    }

    public func getSessionOrCreate(for identifier: String) -> URLSession {
        Log.bgSessionManager("getSessionOrCreate identifier:\(identifier)")
        if let session = syncQueue.sync(execute: { managedSessions[identifier] }) {
            Log.bgSessionManager("fetched session:\(session)")
            return session
        }

        let backgroundUrlSessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        backgroundUrlSessionConfiguration.sessionSendsLaunchEvents = true
        backgroundUrlSessionConfiguration.allowsCellularAccess = true
        backgroundUrlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        backgroundUrlSessionConfiguration
            .httpMaximumConnectionsPerHost = 4 // This limit is not really respected because we are using http/2
        backgroundUrlSessionConfiguration.timeoutIntervalForRequest = 60 * 2 // 2 minutes before timeout
        backgroundUrlSessionConfiguration
            .timeoutIntervalForResource = 60 * 60 * 11 // 11h before giving up (chunk upload session not valid after)
        backgroundUrlSessionConfiguration.networkServiceType = .responsiveData
        backgroundUrlSessionConfiguration.httpAdditionalHeaders = ["User-Agent": Constants.userAgent]
        let session = URLSession(configuration: backgroundUrlSessionConfiguration, delegate: self, delegateQueue: nil)
        syncQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            Log.bgSessionManager("store session:\(session) from identifier:\(identifier)")
            managedSessions[identifier] = session
        }

        Log.bgSessionManager("generated session:\(session) from identifier:\(identifier)")
        return session
    }

    /// Entry point for app delegate
    public func handleEventsForBackgroundURLSession(identifier: String,
                                                    completionHandler: @escaping BackgroundCompletionHandler) {
        Log.bgSessionManager("handleEventsForBackgroundURLSession identifier:\(identifier)")
    }

    public func reconnectBackgroundTasks() {
        Log.bgSessionManager("reconnectBackgroundTasks")
    }

    public func scheduled(task: URLSessionDataTask?, fileUrl: URL?) {
        Log.bgSessionManager("scheduled task:\(task as URLSessionDataTask?)")
    }

    public func rescheduleForBackground(task: URLSessionDataTask, fileUrl: URL) -> String? {
        Log.bgSessionManager("rescheduleForBackground task:\(task)")
        return nil
    }

    // MARK: - URLSessionDataDelegate

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive data: Data) {
        let taskIdentifier = session.identifier(for: dataTask)
        syncQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            if var taskData = tasksData[taskIdentifier] {
                taskData.append(data)
                tasksData[taskIdentifier] = taskData
            } else {
                tasksData[taskIdentifier] = data
            }
        }
    }

    // MARK: - URLSessionDelegate

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Log.bgSessionManager(
            "urlSession session:\(session) didCompleteWithError:\(error as Error?) identifier:\(session.identifier)"
        )
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Log.bgSessionManager("urlSessionDidFinishEvents session:\(session) identifier:\(session.identifier)")
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        Log.bgSessionManager("Session didBecomeInvalidWithError \(session.identifier) \(error?.localizedDescription ?? "")",
                             level: .error)
    }

    // MARK: - BackgroundUploadSessionCompletionable

    func getCompletionHandler(for task: URLSessionUploadTask, session: URLSession) -> RequestCompletionHandler? {
        Log.bgSessionManager("getCompletionHandler :\(session)")
        return nil
    }
}
