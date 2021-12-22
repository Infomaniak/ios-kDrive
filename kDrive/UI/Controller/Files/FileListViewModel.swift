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
    /// SortType
    typealias SortTypeUpdatedCallback = (SortType) -> Void
    /// ListStyle
    typealias ListStyleUpdatedCallback = (ListStyle) -> Void

    var isEmpty: Bool { get }
    var fileCount: Int { get }
    var sortType: SortType { get set }
    var listStyle: ListStyle { get set }

    func getFile(at index: Int) -> File
    func setFile(_ file: File, at index: Int)
    func getAllFiles() -> [File]

    init(driveFileManager: DriveFileManager, currentDirectory: File?)

    var onFileListUpdated: FileListUpdatedCallback? { get set }
    var onSortTypeUpdated: SortTypeUpdatedCallback? { get set }
    var onListStyleUpdated: ListStyleUpdatedCallback? { get set }
}

class ManagedFileListViewModel: FileListViewModel {
    private var driveFileManager: DriveFileManager
    var sortType: SortType {
        didSet {
            updateDataSource()
            onSortTypeUpdated?(sortType)
        }
    }
    var listStyle: ListStyle {
        didSet {
            onListStyleUpdated?(listStyle)
        }
    }

    var currentDirectory: File
    var fileCount: Int {
        return files.count
    }

    var isEmpty: Bool {
        return files.isEmpty
    }

    var onFileListUpdated: FileListUpdatedCallback?
    var onSortTypeUpdated: SortTypeUpdatedCallback?
    var onListStyleUpdated: ListStyleUpdatedCallback?

    private var files: Results<File>
    private var realmObservationToken: NotificationToken?
    private var sortTypeObservation: AnyCancellable?
    private var listStyleObservation: AnyCancellable?

    required init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        self.driveFileManager = driveFileManager
        if let currentDirectory = currentDirectory {
            self.currentDirectory = currentDirectory
        } else {
            self.currentDirectory = driveFileManager.getRootFile()
        }
        self.sortType = FileListOptions.instance.currentSortType
        self.listStyle = FileListOptions.instance.currentStyle
        self.files = driveFileManager.getRealm().objects(File.self).filter(NSPredicate(value: false))

        setupObservation()
        updateDataSource()
    }

    private func setupObservation() {
        sortTypeObservation = FileListOptions.instance.$currentSortType
            .receive(on: RunLoop.main)
            .assign(to: \.sortType, on: self)
        listStyleObservation = FileListOptions.instance.$currentStyle
            .receive(on: RunLoop.main)
            .assign(to: \.listStyle, on: self)
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
                self?.onFileListUpdated?([], [], [], true)
            case .update(let results, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                self?.files = results
                self?.onFileListUpdated?(deletions, insertions, modifications, false)
            case .error(let error):
                DDLogError("[Realm Observation] Error \(error)")
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
