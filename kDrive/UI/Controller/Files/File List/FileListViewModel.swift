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
import kDriveResources
import RealmSwift

enum FileListBarButtonType {
    case selectAll
    case deselectAll
    case loading
    case cancel
    case search
    case emptyTrash
}

enum FileListQuickActionType {
    case file
    case trash
    case multipleSelection
}

enum ControllerPresentationType {
    case push
    case modal
}

@MainActor
class FileListViewModel {
    /// deletions, insertions, modifications, shouldReload
    typealias FileListUpdatedCallback = ([Int], [Int], [Int], Bool) -> Void
    typealias DriveErrorCallback = (DriveError) -> Void
    typealias FilePresentedCallback = (File) -> Void
    /// presentation type, presented viewcontroller, animated
    typealias PresentViewControllerCallback = (ControllerPresentationType, UIViewController, Bool) -> Void
    /// files sent to the panel, panel type
    typealias PresentQuickActionPanelCallback = ([File], FileListQuickActionType) -> Void

    // MARK: - Configuration

    struct Configuration {
        /// Is normal folder hierarchy
        var normalFolderHierarchy = true
        /// Enable or disable upload status displayed in the header (enabled by default)
        var showUploadingFiles = true
        /// Enable or disable multiple selection (enabled by default)
        var isMultipleSelectionEnabled = true
        /// Enable or disable refresh control (enabled by default)
        var isRefreshControlEnabled = true
        /// Is displayed from activities
        var fromActivities = false
        /// Does this folder support "select all" action (no effect if multiple selection is disabled)
        var selectAllSupported = true
        /// Root folder title
        var rootTitle: String?
        /// An icon displayed in the tabBar
        var tabBarIcon = KDriveResourcesAsset.folder
        /// An selected icon displayed in the tabBar
        var selectedTabBarIcon = KDriveResourcesAsset.folderFill
        /// Type of empty view to display
        var emptyViewType: EmptyTableView.EmptyTableViewType
        /// Does this folder support importing files with drop from external app
        var supportsDrop = false
        /// Does this folder support importing files with drag from external app
        var supportDrag = true
        /// Bar buttons showed in the file list
        var leftBarButtons: [FileListBarButtonType]?
        var rightBarButtons: [FileListBarButtonType]?
        var sortingOptions: [SortType] = [.nameAZ, .nameZA, .newer, .older, .biggest, .smallest]
    }

    var currentDirectory: File
    var driveFileManager: DriveFileManager {
        didSet {
            multipleSelectionViewModel?.driveFileManager = driveFileManager
            uploadViewModel?.driveFileManager = driveFileManager
            draggableFileListViewModel?.driveFileManager = driveFileManager
            droppableFileListViewModel?.driveFileManager = driveFileManager
        }
    }

    var isEmpty: Bool {
        return true
    }

    var fileCount: Int {
        return 0
    }

    var isLoading: Bool
    var isBound = false

    @Published var sortType: SortType
    @Published var listStyle: ListStyle
    @Published var title: String
    @Published var isRefreshIndicatorHidden: Bool
    @Published var isEmptyViewHidden: Bool
    @Published var currentLeftBarButtons: [FileListBarButtonType]?
    @Published var currentRightBarButtons: [FileListBarButtonType]?

    var onFileListUpdated: FileListUpdatedCallback?
    var onDriveError: DriveErrorCallback?
    var onPresentQuickActionPanel: PresentQuickActionPanelCallback? {
        didSet {
            multipleSelectionViewModel?.onPresentQuickActionPanel = onPresentQuickActionPanel
        }
    }

    var onFilePresented: FilePresentedCallback? {
        didSet {
            droppableFileListViewModel?.onFilePresented = onFilePresented
        }
    }

    var onPresentViewController: PresentViewControllerCallback? {
        didSet {
            multipleSelectionViewModel?.onPresentViewController = onPresentViewController
        }
    }

    internal var sortTypeObservation: AnyCancellable?
    internal var listStyleObservation: AnyCancellable?
    internal var bindStore = Set<AnyCancellable>()

    var uploadViewModel: UploadCardViewModel?
    var multipleSelectionViewModel: MultipleSelectionFileListViewModel?
    var draggableFileListViewModel: DraggableFileListViewModel?
    var droppableFileListViewModel: DroppableFileListViewModel?

    var configuration: Configuration

    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        fatalError(#function + " needs to be overridden")
    }

    init(configuration: Configuration, driveFileManager: DriveFileManager, currentDirectory: File) {
        self.configuration = configuration
        self.driveFileManager = driveFileManager
        self.currentDirectory = currentDirectory
        self.sortType = FileListOptions.instance.currentSortType
        self.listStyle = FileListOptions.instance.currentStyle
        self.isRefreshIndicatorHidden = true
        self.isEmptyViewHidden = true
        self.isLoading = false
        self.currentLeftBarButtons = configuration.leftBarButtons
        self.currentRightBarButtons = configuration.rightBarButtons

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

        if configuration.supportDrag {
            self.draggableFileListViewModel = DraggableFileListViewModel(driveFileManager: driveFileManager)
        }

        if configuration.supportsDrop {
            self.droppableFileListViewModel = DroppableFileListViewModel(driveFileManager: driveFileManager, currentDirectory: self.currentDirectory)
        }

        setupObservation()
    }

    private func setupObservation() {
        sortTypeObservation = FileListOptions.instance.$currentSortType
            .receive(on: RunLoop.main)
            .sink { [weak self] sortType in
                self?.sortType = sortType
                self?.sortingChanged()
            }
        listStyleObservation = FileListOptions.instance.$currentStyle
            .receive(on: RunLoop.main)
            .assignNoRetain(to: \.listStyle, on: self)

        multipleSelectionViewModel?.$leftBarButtons.sink { [weak self] leftBarButtons in
            if self?.multipleSelectionViewModel?.isMultipleSelectionEnabled == true {
                self?.currentLeftBarButtons = leftBarButtons
            } else {
                self?.currentLeftBarButtons = self?.configuration.leftBarButtons
            }
        }.store(in: &bindStore)

        multipleSelectionViewModel?.$rightBarButtons.sink { [weak self] rightBarButtons in
            if self?.multipleSelectionViewModel?.isMultipleSelectionEnabled == true {
                self?.currentRightBarButtons = rightBarButtons
            } else {
                self?.currentRightBarButtons = self?.configuration.rightBarButtons
            }
        }.store(in: &bindStore)
    }

    func barButtonPressed(type: FileListBarButtonType) {
        if multipleSelectionViewModel?.isMultipleSelectionEnabled == true {
            multipleSelectionViewModel?.barButtonPressed(type: type)
        } else {
            switch type {
            case .search:
                let searchViewController = SearchViewController.instantiateInNavigationController(driveFileManager: driveFileManager)
                onPresentViewController?(.modal, searchViewController, true)
            default:
                break
            }
        }
    }

    func sortingChanged() {}

    func showLoadingIndicatorIfNeeded() {
        // Show refresh control if loading is slow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if self.isLoading && self.isRefreshIndicatorHidden {
                self.isRefreshIndicatorHidden = false
            }
        }
    }

    func fetchFiles(id: Int, withExtras: Bool = false, page: Int = 1, sortType: SortType = .nameAZ, forceRefresh: Bool = false, completion: @escaping (File?, [File]?, Error?) -> Void) {}

    func loadActivities() {}

    func loadFiles(page: Int = 1, forceRefresh: Bool = false) {}

    func didSelectFile(at index: Int) {
        guard let file: File = getFile(at: index) else { return }
        if ReachabilityListener.instance.currentStatus == .offline && !file.isDirectory && !file.isAvailableOffline {
            return
        }
        onFilePresented?(file)
    }

    func didTapMore(at index: Int) {
        guard let file: File = getFile(at: index) else { return }
        onPresentQuickActionPanel?([file], .file)
    }

    func didSelectSwipeAction(_ action: SwipeCellAction, at index: Int) {
        if let file = getFile(at: index) {
            switch action {
            case .share:
                let shareVC = ShareAndRightsViewController.instantiate(driveFileManager: driveFileManager, file: file)
                onPresentViewController?(.push, shareVC, true)
            case .delete:
                // Keep the filename before it is invalidated
                let filename = file.name
                driveFileManager.deleteFile(file: file) { cancelAction, error in
                    if let error = error {
                        UIConstants.showSnackBar(message: error.localizedDescription)
                    } else {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarMoveTrashConfirmation(filename), action: .init(title: KDriveResourcesStrings.Localizable.buttonCancel) {
                            guard let cancelId = cancelAction?.id else { return }
                            self.driveFileManager.cancelAction(cancelId: cancelId) { error in
                                if error == nil {
                                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.allTrashActionCancelled)
                                }
                            }
                        })
                    }
                }
            default:
                break
            }
        }
    }

    func getFile(at index: Int) -> File? {
        fatalError(#function + " needs to be overridden")
    }

    func getAllFiles() -> [File] {
        fatalError(#function + " needs to be overridden")
    }

    func getSwipeActions(at index: Int) -> [SwipeCellAction]? {
        if configuration.fromActivities || listStyle == .grid {
            return nil
        }
        var actions = [SwipeCellAction]()
        if let file = getFile(at: index),
           let rights = file.rights {
            if rights.share {
                actions.append(.share)
            }
            if rights.delete {
                actions.append(.delete)
            }
        }

        return actions
    }

    func forceRefresh() {
        isLoading = false
        isRefreshIndicatorHidden = false
        loadFiles(page: 1, forceRefresh: true)
    }

    func onViewDidLoad() {
        loadFiles()
    }

    func onViewWillAppear() {
        if currentDirectory.fullyDownloaded && fileCount > 0 {
            loadActivities()
        }
    }
}

class ManagedFileListViewModel: FileListViewModel {
    private var realmObservationToken: NotificationToken?

    internal var files: AnyRealmCollection<File>!
    override var isEmpty: Bool {
        return files.isEmpty
    }

    override var fileCount: Int {
        return files.count
    }

    override func sortingChanged() {
        updateDataSource()
    }

    func updateDataSource() {
        realmObservationToken?.invalidate()
        realmObservationToken = files.sorted(by: [
            SortDescriptor(keyPath: \File.type, ascending: true),
            SortDescriptor(keyPath: \File.rawVisibility, ascending: false),
            sortType.value.sortDescriptor
        ]).observe(on: .main) { [weak self] change in
            switch change {
            case .initial(let results):
                self?.files = AnyRealmCollection(results)
                self?.isEmptyViewHidden = !results.isEmpty
                self?.onFileListUpdated?([], [], [], true)
            case .update(let results, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                self?.files = AnyRealmCollection(results)
                self?.isEmptyViewHidden = !results.isEmpty
                self?.onFileListUpdated?(deletions, insertions, modifications, false)
            case .error(let error):
                DDLogError("[Realm Observation] Error \(error)")
            }
        }
    }

    override func getFile(at index: Int) -> File? {
        return index < fileCount ? files[index] : nil
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
