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
import RealmSwift
import InfomaniakLogin

public class DownloadTask: Object {

    @objc public dynamic var fileId: Int = 0
    @objc public dynamic var driveId: Int = 0
    @objc public dynamic var userId: Int = 0
    @objc public dynamic var sessionUrl: String = ""
    public var cancellable: Bool = false
    public var task: URLSessionDownloadTask?
    public var progress: Int?

    init(fileId: Int, driveId: Int, userId: Int, sessionUrl: String) {
        self.fileId = fileId
        self.driveId = driveId
        self.sessionUrl = sessionUrl
        self.userId = userId
    }

    public override init() {
    }

    public func cancel() {
        if cancellable {
            task?.cancel()
        }
    }

}

public class DownloadQueue: NSObject, URLSessionDownloadDelegate {

    private var currentSessions = [URL: DownloadTask]()

    public static let instance = DownloadQueue()
    public static let downloadQueueIdentifier = "com.infomaniak.background.download"

    public var backgroundCompletionHandler: (() -> Void)?
    private var backgroundUrlSessionConfiguration: URLSessionConfiguration!
    private var foregroundUrlSessionConfiguration: URLSessionConfiguration!
    private var backgroundDownloadSession: URLSession!
    private var foregroundDownloadSession: URLSession!
    private let dispatchQueue = DispatchQueue(label: "ch.drive.infomaniak.download", qos: .userInitiated, attributes: .concurrent)
    private let dispatchSemaphore = DispatchSemaphore(value: 4)
    private var observations = (
        didDownloadFile: [UUID: (DownloadedFileId, DriveError?) -> Void](),
        progressDownloadFile: [UUID: (DownloadedFileId, Int) -> Void]()
    )

    private override init() {
        super.init()
        backgroundUrlSessionConfiguration = URLSessionConfiguration.background(withIdentifier: DownloadQueue.downloadQueueIdentifier)
        backgroundUrlSessionConfiguration.sessionSendsLaunchEvents = true
        backgroundUrlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = true
        backgroundUrlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        backgroundDownloadSession = URLSession(configuration: backgroundUrlSessionConfiguration, delegate: self, delegateQueue: nil)
        //Hack to reconnect to the background transfers as suggested by Apple: https://developer.apple.com/forums/thread/77666?page=2
        backgroundDownloadSession.getAllTasks { (tasks) in
            for task in tasks {
                task.resume()
            }
        }

        foregroundUrlSessionConfiguration = URLSessionConfiguration.default
        foregroundUrlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = false
        foregroundUrlSessionConfiguration.allowsCellularAccess = true
        foregroundUrlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        foregroundDownloadSession = URLSession(configuration: foregroundUrlSessionConfiguration, delegate: nil, delegateQueue: nil)
    }

    public func temporaryDownloadFile(file: File, completion: @escaping (DriveError?) -> ()) -> DownloadTask? {
        if !isFileAlreadyInQueue(file) {
            let sessionUrl = URL(string: ApiRoutes.downloadFile(file: file))!
            let downloadTask = DownloadTask(fileId: file.id, driveId: file.driveId, userId: AccountManager.instance.currentUserId, sessionUrl: sessionUrl.absoluteString)
            downloadTask.cancellable = true
            currentSessions[sessionUrl] = downloadTask

            var request = URLRequest(url: sessionUrl)
            request.setValue("Bearer \(AccountManager.instance.currentAccount.token.accessToken)", forHTTPHeaderField: "Authorization")
            let task = foregroundDownloadSession.downloadTask(with: request) { [unowned self] (fileUrl, urlResponse, error) in
                currentSessions[sessionUrl] = nil
                if let location = fileUrl {
                    do {
                        try moveDownloadedFile(at: location, for: downloadTask)
                        completion(nil)
                    } catch {
                        completion(.localError)
                    }
                } else if let error = error as NSError? {
                    if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                        completion(.taskCancelled)
                    } else {
                        completion(.localError)
                    }
                } else {
                    completion(.serverError)
                }
            }
            downloadTask.task = task
            task.resume()
            return downloadTask
        } else {
            return getDownloadTaskFor(fileId: file.id)
        }
    }

    public func addToQueue(file: File, userId: Int = AccountManager.instance.currentUserId) {
        if UserDefaults.shared.isWifiOnly && ReachabilityListener.instance.currentStatus != .wifi {
            return
        }
        if !isFileAlreadyInQueue(file) {
            let sessionUrl = URL(string: ApiRoutes.downloadFile(file: file))!
            let task = DownloadTask(fileId: file.id, driveId: file.driveId, userId: userId, sessionUrl: sessionUrl.absoluteString)

            let realm = DriveFileManager.constants.uploadsRealm
            try? realm.write {
                realm.add(task)
            }
            currentSessions[sessionUrl] = task.freeze()

            downloadFile(sessionUrl: sessionUrl, task: task.freeze())
        }
    }

    private func isFileAlreadyInQueue(_ file: File) -> Bool {
        let sessionUrl = URL(string: ApiRoutes.downloadFile(file: file))!
        return currentSessions[sessionUrl] != nil
    }

    private func downloadFile(sessionUrl: URL, task: DownloadTask) {
        dispatchQueue.async { [self] in
            dispatchSemaphore.wait()
            if let userToken = AccountManager.instance.getTokenForUserId(task.userId),
                let drive = AccountManager.instance.getDrive(for: task.userId, driveId: task.driveId),
                let driveFileManager = AccountManager.instance.getDriveFileManager(for: drive) {
                driveFileManager.apiFetcher.performAuthenticatedRequest(token: userToken) { (token, error) in
                    if let token = token {
                        var request = URLRequest(url: sessionUrl)
                        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
                        let task = backgroundDownloadSession.downloadTask(with: request)
                        currentSessions[sessionUrl]?.task = task
                        task.resume()
                    } else {
                        dispatchSemaphore.signal()
                    }
                }
            } else {
                dispatchSemaphore.signal()
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let sessionUrl = task.originalRequest?.url,
            let downloadTask = getDownloadTaskFor(url: sessionUrl) {

            let realm = DriveFileManager.constants.uploadsRealm
            if let task = DriveFileManager.constants.uploadsRealm.objects(DownloadTask.self)
                .filter(NSPredicate(format: "sessionUrl = %@", sessionUrl.absoluteString)).first {
                try? realm.write {
                    realm.delete(task)
                }
            }

            downloadCompleted(task: downloadTask, error: error == nil ? nil : .serverError)
            if backgroundCompletionHandler == nil && currentSessions.count > 0 {
                dispatchSemaphore.signal()
            }
            currentSessions[sessionUrl] = nil
        }
    }

    private func downloadCompleted(task: DownloadTask, error: DriveError?) {
        observations.didDownloadFile.values.forEach { closure in
            closure(task.fileId, error)
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let sessionUrl = downloadTask.originalRequest?.url,
            let task = getDownloadTaskFor(url: sessionUrl) {
            let percent = Int(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100.0)
            task.task = downloadTask
            task.progress = percent
            observations.progressDownloadFile.forEach { observation in
                observation.value(task.fileId, percent)
            }
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let sessionUrl = downloadTask.originalRequest?.url,
            let downloadTask = getDownloadTaskFor(url: sessionUrl) {
            do {
                try moveDownloadedFile(at: location, for: downloadTask)
            } catch {
                downloadCompleted(task: downloadTask, error: .localError)
            }
        }
    }

    private func moveDownloadedFile(at url: URL, for task: DownloadTask) throws {
        if let drive = DriveInfosManager.instance.getDrive(id: task.driveId, userId: AccountManager.instance.currentUserId),
            let file = AccountManager.instance.getDriveFileManager(for: drive)?.getCachedFile(id: task.fileId, freeze: false) {
            if FileManager.default.fileExists(atPath: file.localUrl.path) {
                try? FileManager.default.removeItem(at: file.localUrl)
            }
            try FileManager.default.createDirectory(at: file.localUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.moveItem(at: url, to: file.localUrl)
            try? file.realm?.write {
                file.applyLastModifiedDateToLocalFile()
            }
        } else {
            throw DriveError.localError
        }
    }

    private func getDownloadTaskFor(url: URL) -> DownloadTask? {
        if let task = currentSessions[url] {
            return task
        } else {
            if let task = DriveFileManager.constants.uploadsRealm.objects(DownloadTask.self)
                .filter(NSPredicate(format: "sessionUrl = %@", url.absoluteString)).first {
                return task.freeze()
            } else {
                return nil
            }
        }
    }

    public func getDownloadTaskFor(fileId: Int) -> DownloadTask? {
        return currentSessions.values.first { (task) -> Bool in
            task.fileId == fileId
        }
    }

}

//MARK: - Observation
extension DownloadQueue {
    public typealias DownloadedFileId = Int
    @discardableResult
    public func observeFileDownloaded<T: AnyObject>(_ observer: T, fileId: Int? = nil, using closure: @escaping (DownloadedFileId, DriveError?) -> Void)
        -> ObservationToken {
        let key = UUID()
        observations.didDownloadFile[key] = { [weak self, weak observer] downloadedFileId, error in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard let _ = observer else {
                self?.observations.didDownloadFile.removeValue(forKey: key)
                return
            }

            if fileId == nil || downloadedFileId == fileId {
                closure(downloadedFileId, error)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didDownloadFile.removeValue(forKey: key)
        }
    }

    @discardableResult
    public func observeFileDownloadedProgress<T: AnyObject>(_ observer: T, fileId: Int? = nil, using closure: @escaping (DownloadedFileId, Int) -> Void)
        -> ObservationToken {
        let key = UUID()
        observations.progressDownloadFile[key] = { [weak self, weak observer] downloadedFileId, progress in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard let _ = observer else {
                self?.observations.progressDownloadFile.removeValue(forKey: key)
                return
            }

            if fileId == nil || downloadedFileId == fileId {
                closure(downloadedFileId, progress)
            }
        }


        return ObservationToken { [weak self] in
            self?.observations.progressDownloadFile.removeValue(forKey: key)
        }
    }
}
