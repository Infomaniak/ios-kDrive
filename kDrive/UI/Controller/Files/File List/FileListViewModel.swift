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
import Combine
import Foundation
import kDriveCore
import RealmSwift

@MainActor
class FileListViewModel {
    /// deletions, insertions, modifications, shouldReload
    typealias FileListUpdatedCallback = ([Int], [Int], [Int], Bool) -> Void
    typealias DriveErrorCallback = (DriveError) -> Void
    typealias FilePresentedCallback = (File) -> Void

    var currentDirectory: File
    var driveFileManager: DriveFileManager
    var isEmpty: Bool {
        return true
    }

    var fileCount: Int {
        return 0
    }

    var isLoading: Bool

    @Published var sortType: SortType
    @Published var listStyle: ListStyle
    @Published var title: String
    @Published var isRefreshIndicatorHidden: Bool
    @Published var isEmptyViewHidden: Bool

    var onFileListUpdated: FileListUpdatedCallback?
    var onDriveError: DriveErrorCallback?
    var onFilePresented: FilePresentedCallback?

    private var sortTypeObservation: AnyCancellable?
    private var listStyleObservation: AnyCancellable?

    var uploadViewModel: UploadCardViewModel?
    var multipleSelectionViewModel: MultipleSelectionFileListViewModel?

    init(configuration: FileListViewController.Configuration, driveFileManager: DriveFileManager, currentDirectory: File?) {
        self.driveFileManager = driveFileManager
        if let currentDirectory = currentDirectory {
            self.currentDirectory = currentDirectory
        } else {
            self.currentDirectory = driveFileManager.getRootFile()
        }
        self.sortType = FileListOptions.instance.currentSortType
        self.listStyle = FileListOptions.instance.currentStyle
        self.isRefreshIndicatorHidden = true
        self.isEmptyViewHidden = true
        self.isLoading = false

        if self.currentDirectory.isRoot {
            if let rootTitle = configuration.rootTitle {
                self.title = rootTitle
            } else {
                self.title = driveFileManager.drive.name
            }
        } else {
            self.title = self.currentDirectory.name
        }

        if configuration.showUploadingFiles {
            self.uploadViewModel = UploadCardViewModel(uploadDirectory: currentDirectory, driveFileManager: driveFileManager)
        }

        if configuration.isMultipleSelectionEnabled {
            self.multipleSelectionViewModel = MultipleSelectionFileListViewModel(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: self.currentDirectory)
        }

        setupObservation()
    }

    private func setupObservation() {
        sortTypeObservation = FileListOptions.instance.$currentSortType
            .receive(on: RunLoop.main)
            .sink { [weak self] sortType in
                self?.sortType = sortType
                self?.updateDataSource()
            }
        listStyleObservation = FileListOptions.instance.$currentStyle
            .receive(on: RunLoop.main)
            .assignNoRetain(to: \.listStyle, on: self)
    }

    func didSelectFile(at index: Int) {}
    func getFile(at index: Int) -> File {
        fatalError(#function + " needs to be overridden")
    }

    func setFile(_ file: File, at index: Int) {}
    func getAllFiles() -> [File] {
        fatalError(#function + " needs to be overridden")
    }

    func forceRefresh() {}
    func updateDataSource() {}

    func onViewDidLoad() {}
    func onViewWillAppear() {}
}

class ManagedFileListViewModel: FileListViewModel {
    private var realmObservationToken: NotificationToken?

    private var files: Results<File>
    override var isEmpty: Bool {
        return files.isEmpty
    }

    override var fileCount: Int {
        return files.count
    }

    override required init(configuration: FileListViewController.Configuration, driveFileManager: DriveFileManager, currentDirectory: File?) {
        self.files = driveFileManager.getRealm().objects(File.self).filter(NSPredicate(value: false))
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
    }

    override public func forceRefresh() {
        isLoading = false
        isRefreshIndicatorHidden = false
        loadFiles(page: 1, forceRefresh: true)
    }

    override public func onViewDidLoad() {
        updateDataSource()
        loadFiles()
    }

    override public func onViewWillAppear() {
        if currentDirectory.fullyDownloaded && !files.isEmpty {
            loadActivities()
        }
    }

    override func updateDataSource() {
        realmObservationToken?.invalidate()
        realmObservationToken = currentDirectory.children.sorted(by: [
            SortDescriptor(keyPath: \File.type, ascending: true),
            SortDescriptor(keyPath: \File.rawVisibility, ascending: false),
            sortType.value.sortDescriptor
        ]).observe(on: .main) { [weak self] change in
            switch change {
            case .initial(let results):
                self?.files = results
                self?.isEmptyViewHidden = !results.isEmpty
                self?.onFileListUpdated?([], [], [], true)
            case .update(let results, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                self?.files = results
                self?.isEmptyViewHidden = !results.isEmpty
                self?.onFileListUpdated?(deletions, insertions, modifications, false)
            case .error(let error):
                DDLogError("[Realm Observation] Error \(error)")
            }
        }
    }

    private func loadFiles(page: Int = 1, forceRefresh: Bool = false) {
        guard !isLoading || page > 1 else { return }

        if currentDirectory.fullyDownloaded && !forceRefresh {
            loadActivities()
        } else {
            isLoading = true
            if page == 1 {
                // Show refresh control if loading is slow
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if self.isLoading && self.isRefreshIndicatorHidden {
                        self.isRefreshIndicatorHidden = false
                    }
                }
            }

            driveFileManager.getFile(id: currentDirectory.id, page: page, sortType: sortType, forceRefresh: forceRefresh) { [weak self] file, _, error in
                self?.isLoading = false
                self?.isRefreshIndicatorHidden = true
                if let fetchedCurrentDirectory = file {
                    if !fetchedCurrentDirectory.fullyDownloaded {
                        self?.loadFiles(page: page + 1)
                    } else {
                        self?.loadActivities()
                    }
                } else if let error = error as? DriveError {
                    self?.onDriveError?(error)
                }
            }
        }
    }

    private func loadActivities() {
        driveFileManager.getFolderActivities(file: currentDirectory) { [weak self] _, _, error in
            if let error = error as? DriveError {
                self?.onDriveError?(error)
            }
        }
    }

    override func didSelectFile(at index: Int) {
        let file = getFile(at: index)
        if ReachabilityListener.instance.currentStatus == .offline && !file.isDirectory && !file.isAvailableOffline {
            return
        }
        onFilePresented?(file)
    }

    override func getFile(at index: Int) -> File {
        return files[index]
    }

    override func setFile(_ file: File, at index: Int) {
        // files[index] = file
    }

    override func getAllFiles() -> [File] {
        return Array(files.freeze())
    }
}

extension Publisher where Self.Failure == Never {
    func assignNoRetain<Root>(to keyPath: ReferenceWritableKeyPath<Root, Self.Output>, on object: Root) -> AnyCancellable where Root: AnyObject {
        sink { [weak object] value in
            object?[keyPath: keyPath] = value
        }
    }

    func receiveOnMain(store: inout Set<AnyCancellable>, receiveValue: @escaping ((Self.Output) -> Void)) {
        receive(on: RunLoop.main)
            .sink(receiveValue: receiveValue)
            .store(in: &store)
    }
}
