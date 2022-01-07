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

protocol FileListViewModel {
    /// deletions, insertions, modifications, shouldReload
    typealias FileListUpdatedCallback = ([Int], [Int], [Int], Bool) -> Void
    var isEmpty: Bool { get }
    var fileCount: Int { get }
    var sortType: SortType { get set }
    var sortTypePublisher: Published<SortType>.Publisher { get }
    var listStyle: ListStyle { get set }
    var listStylePublisher: Published<ListStyle>.Publisher { get }
    var title: String { get set }
    var titlePublisher: Published<String>.Publisher { get }
    var isRefreshIndicatorHidden: Bool { get set }
    var isRefreshIndicatorHiddenPublisher: Published<Bool>.Publisher { get }
    var isEmptyViewHidden: Bool { get set }
    var isEmptyViewHiddenPublisher: Published<Bool>.Publisher { get }

    func getFile(at index: Int) -> File
    func setFile(_ file: File, at index: Int)
    func getAllFiles() -> [File]

    func forceRefresh()

    func onViewDidLoad()
    func onViewWillAppear()

    init(configuration: FileListViewController.Configuration, driveFileManager: DriveFileManager, currentDirectory: File?)

    var onFileListUpdated: FileListUpdatedCallback? { get set }
}

class ManagedFileListViewModel: FileListViewModel {
    private var driveFileManager: DriveFileManager

    @Published var sortType: SortType
    var sortTypePublisher: Published<SortType>.Publisher { $sortType }

    @Published var listStyle: ListStyle
    var listStylePublisher: Published<ListStyle>.Publisher { $listStyle }

    @Published var title: String
    var titlePublisher: Published<String>.Publisher { $title }

    @Published var isRefreshIndicatorHidden: Bool
    var isRefreshIndicatorHiddenPublisher: Published<Bool>.Publisher { $isRefreshIndicatorHidden }

    @Published var isEmptyViewHidden: Bool
    var isEmptyViewHiddenPublisher: Published<Bool>.Publisher { $isEmptyViewHidden }

    var currentDirectory: File
    var fileCount: Int {
        return files.count
    }

    var isEmpty: Bool {
        return files.isEmpty
    }

    var onFileListUpdated: FileListUpdatedCallback?

    private var files: Results<File>
    private var isLoading: Bool

    private var realmObservationToken: NotificationToken?
    private var sortTypeObservation: AnyCancellable?
    private var listStyleObservation: AnyCancellable?

    required init(configuration: FileListViewController.Configuration, driveFileManager: DriveFileManager, currentDirectory: File?) {
        self.driveFileManager = driveFileManager
        if let currentDirectory = currentDirectory {
            self.currentDirectory = currentDirectory
        } else {
            self.currentDirectory = driveFileManager.getRootFile()
        }
        self.sortType = FileListOptions.instance.currentSortType
        self.listStyle = FileListOptions.instance.currentStyle
        self.files = driveFileManager.getRealm().objects(File.self).filter(NSPredicate(value: false))
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

        setupObservation()
    }

    public func forceRefresh() {
        isLoading = false
        isRefreshIndicatorHidden = false
        loadFiles(page: 1, forceRefresh: true)
    }

    public func onViewDidLoad() {
        updateDataSource()
        loadFiles()
    }

    public func onViewWillAppear() {
        if currentDirectory.fullyDownloaded && !files.isEmpty {
            loadActivities()
        }
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

    private func updateDataSource() {
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

            driveFileManager.getFile(id: currentDirectory.id, page: page, sortType: sortType, forceRefresh: forceRefresh) { [weak self] file, _, _ in
                self?.isLoading = false
                self?.isRefreshIndicatorHidden = true
                if let fetchedCurrentDirectory = file {
                    if !fetchedCurrentDirectory.fullyDownloaded {
                        self?.loadFiles(page: page + 1)
                    } else {
                        self?.loadActivities()
                    }
                } else {
                    // TODO: report error
                }
            }
        }
    }

    private func loadActivities() {
        driveFileManager.getFolderActivities(file: currentDirectory) { [weak self] _, _, error in
            if let error = error {
                if let error = error as? DriveError, error == .objectNotFound {
                } else {}
            }
        }
    }

    func getFile(at index: Int) -> File {
        return files[index]
    }

    func setFile(_ file: File, at index: Int) {
        // files[index] = file
    }

    func getAllFiles() -> [File] {
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
