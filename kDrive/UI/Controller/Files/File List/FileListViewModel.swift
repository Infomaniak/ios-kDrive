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
import InfomaniakCore
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
    case searchFilters
    case photoSort
    case addFolder
    case downloadAll
}

enum FileListQuickActionType {
    case file
    case trash
    case multipleSelection(onlyDownload: Bool)
}

enum ControllerPresentationType {
    case push
    case modal
}

@MainActor
class FileListViewModel: SelectDelegate {
    /// deletions, insertions, modifications, moved, isEmpty, shouldReload
    typealias FileListUpdatedCallback = ([Int], [Int], [Int], [(source: Int, target: Int)], Bool, Bool) -> Void
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
        /// To know from which view it is displayed
        var presentationOrigin = PresentationOrigin.fileList
        /// Does this folder support "select all" action (no effect if multiple selection is disabled)
        var selectAllSupported = true
        /// Root folder title
        var rootTitle: String?
        /// An icon displayed in the tabBar
        var tabBarIcon = KDriveResourcesAsset.folder
        /// An selected icon displayed in the tabBar
        var selectedTabBarIcon = KDriveResourcesAsset.folderFilledTab
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
        var matomoViewPath = ["FileList"]
    }

    weak var viewControllerDismissable: ViewControllerDismissable?

    var realmObservationToken: NotificationToken?
    var currentDirectoryObservationToken: NotificationToken?

    var currentDirectory: File
    var driveFileManager: DriveFileManager {
        didSet {
            multipleSelectionViewModel?.driveFileManager = driveFileManager
            uploadViewModel?.driveFileManager = driveFileManager
            draggableFileListViewModel?.driveFileManager = driveFileManager
            droppableFileListViewModel?.driveFileManager = driveFileManager
        }
    }

    var observedFiles: AnyRealmCollection<File> = AnyRealmCollection(List<File>())

    var isLoading: Bool

    @Published var sortType: SortType
    @Published var listStyle: ListStyle
    @Published var title: String
    @Published var isRefreshing: Bool
    @Published var currentLeftBarButtons: [FileListBarButtonType]?
    @Published var currentRightBarButtons: [FileListBarButtonType]?
    /// Public facing collection of observed files
    @Published var files: [File] = []
    @Published var isShowingEmptyView = false

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

    var sortTypeObservation: AnyCancellable?
    var listStyleObservation: AnyCancellable?
    var bindStore = Set<AnyCancellable>()

    var uploadViewModel: UploadCardViewModel?
    var multipleSelectionViewModel: MultipleSelectionFileListViewModel?
    var draggableFileListViewModel: DraggableFileListViewModel?
    var droppableFileListViewModel: DroppableFileListViewModel?

    var configuration: Configuration

    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        Logging.functionOverrideError(#function)
    }

    init(configuration: Configuration, driveFileManager: DriveFileManager, currentDirectory: File) {
        self.configuration = configuration
        self.driveFileManager = driveFileManager
        self.currentDirectory = currentDirectory
        sortType = FileListOptions.instance.currentSortType
        listStyle = FileListOptions.instance.currentStyle
        isRefreshing = false
        isLoading = false
        currentLeftBarButtons = configuration.leftBarButtons
        currentRightBarButtons = configuration.rightBarButtons

        if self.currentDirectory.isRoot {
            if let rootTitle = configuration.rootTitle {
                title = rootTitle
            } else {
                title = driveFileManager.drive.name
            }
        } else {
            title = self.currentDirectory.formattedLocalizedName(drive: driveFileManager.drive)
        }

        if configuration.showUploadingFiles {
            uploadViewModel = UploadCardViewModel(uploadDirectory: currentDirectory, driveFileManager: driveFileManager)
        }

        if configuration.isMultipleSelectionEnabled {
            multipleSelectionViewModel = MultipleSelectionFileListViewModel(
                configuration: configuration,
                driveFileManager: driveFileManager,
                currentDirectory: self.currentDirectory
            )
        }

        if configuration.supportDrag {
            draggableFileListViewModel = DraggableFileListViewModel(driveFileManager: driveFileManager)
        }

        if configuration.supportsDrop {
            droppableFileListViewModel = DroppableFileListViewModel(
                driveFileManager: driveFileManager,
                currentDirectory: self.currentDirectory
            )
        }
    }

    func updateRealmObservation() {
        realmObservationToken?.invalidate()
        realmObservationToken = observedFiles
            .observe(keyPaths: FileViewModel.observedProperties, on: .main) { [weak self] change in
                guard let self,
                      !self.currentDirectory.isInvalidated else {
                    return
                }

                let newResults: AnyRealmCollection<File>?
                switch change {
                case .initial(let results):
                    newResults = results
                    SentryDebug.filesObservationBreadcrumb(state: "initial")
                case .update(let results, _, _, _):
                    newResults = results
                    SentryDebug.filesObservationBreadcrumb(state: "update")
                case .error(let error):
                    DDLogError("[Realm Observation] Error \(error)")
                    newResults = nil
                }

                guard let newResults else { return }
                currentDirectory = getRefreshedCurrentDirectory()
                let resultFiles = Array(newResults.freezeIfNeeded())
                resultFiles.first?.isFirstInList = true
                resultFiles.last?.isLastInList = true
                files = resultFiles
                isShowingEmptyView = shouldShowEmptyView()
            }

        currentDirectoryObservationToken?.invalidate()
        guard currentDirectory.isManagedByRealm,
              !currentDirectory.isInvalidated,
              let liveCurrentDirectory = currentDirectory.thaw() else { return }
        currentDirectoryObservationToken = liveCurrentDirectory
            .observe(keyPaths: ["lastCursor", "fullyDownloaded"],
                     on: .main) { [weak self] change in
                guard let self else { return }

                switch change {
                case .change:
                    currentDirectory = getRefreshedCurrentDirectory()
                    isShowingEmptyView = shouldShowEmptyView()
                default:
                    break
                }
            }
    }

    func shouldShowEmptyView() -> Bool {
        files.isEmpty && currentDirectory.fullyDownloaded
    }

    func startObservation() {
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

    func barButtonPressed(sender: Any? = nil, type: FileListBarButtonType) {
        if multipleSelectionViewModel?.isMultipleSelectionEnabled == true {
            multipleSelectionViewModel?.barButtonPressed(type: type)
        }
    }

    func listStyleButtonPressed() {
        FileListOptions.instance.currentStyle = listStyle == .grid ? .list : .grid
        MatomoUtils.track(
            eventWithCategory: .displayList,
            name: FileListOptions.instance.currentStyle == .grid ? "viewGrid" : "viewList"
        )
    }

    func sortButtonPressed() {
        let floatingPanelViewController = FloatingPanelSelectOptionViewController<SortType>
            .instantiatePanel(options: configuration.sortingOptions,
                              selectedOption: sortType,
                              headerTitle: KDriveResourcesStrings.Localizable.sortTitle,
                              delegate: self)
        onPresentViewController?(.modal, floatingPanelViewController, true)
    }

    /// Called when sortType is updated
    func sortingChanged() {
        observedFiles = AnyRealmCollection(observedFiles.filesSorted(by: sortType))
        updateRealmObservation()
    }

    func showLoadingIndicatorIfNeeded() {
        // Show refresh control if loading is slow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if isLoading && !isRefreshing {
                isRefreshing = true
            }
        }
    }

    func startRefreshing(cursor: String?) {
        isLoading = true

        if cursor == nil {
            showLoadingIndicatorIfNeeded()
        }
    }

    func endRefreshing() {
        isLoading = false
        isRefreshing = false
        currentDirectory = getRefreshedCurrentDirectory()
        isShowingEmptyView = currentDirectory.children.isEmpty && currentDirectory.fullyDownloaded
    }

    func loadActivities() async throws {
        // Implemented by subclasses
    }

    func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        // Implemented by subclasses
    }

    func didSelectFile(at indexPath: IndexPath) {
        guard let file: File = getFile(at: indexPath) else { return }
        if ReachabilityListener.instance.currentStatus == .offline && !file.isDirectory && !file.isAvailableOffline {
            return
        }
        onFilePresented?(file)
    }

    func didTapMore(at indexPath: IndexPath) {
        guard let file: File = getFile(at: indexPath) else { return }
        onPresentQuickActionPanel?([file], .file)
    }

    func didSelectSwipeAction(_ action: SwipeCellAction, at indexPath: IndexPath) {
        if let file = getFile(at: indexPath) {
            switch action {
            case .share:
                MatomoUtils.track(eventWithCategory: .fileListFileAction, name: "swipeShareAndRights")
                let shareVC = ShareAndRightsViewController.instantiate(driveFileManager: driveFileManager, file: file)
                onPresentViewController?(.push, shareVC, true)
            case .delete:
                MatomoUtils.track(eventWithCategory: .fileListFileAction, name: "swipePutInTrash")
                // Keep the filename before it is invalidated
                Task { [proxyFile = file.proxify(), proxyParent = currentDirectory.proxify(), filename = file.name] in
                    do {
                        let cancelResponse = try await driveFileManager.delete(file: proxyFile)
                        UIConstants.showCancelableSnackBar(
                            message: KDriveResourcesStrings.Localizable.snackbarMoveTrashConfirmation(filename),
                            cancelSuccessMessage: KDriveResourcesStrings.Localizable.allTrashActionCancelled,
                            cancelableResponse: cancelResponse,
                            parentFile: proxyParent,
                            driveFileManager: driveFileManager
                        )
                    } catch {
                        UIConstants.showSnackBarIfNeeded(error: error)
                    }
                }
            default:
                break
            }
        }
    }

    func getRefreshedCurrentDirectory() -> File {
        // Directory is not managed by realm so there is no concept of "refresh"
        guard currentDirectory.isManagedByRealm else { return currentDirectory }

        // Directory is managed by realm get live version if it still exists
        return currentDirectory.thaw()?.freeze() ?? currentDirectory
    }

    func getFile(at indexPath: IndexPath) -> File? {
        guard let file = files[safe: indexPath.item], !file.isInvalidated else {
            return nil
        }

        return file.freezeIfNeeded()
    }

    func getSwipeActions(at indexPath: IndexPath) -> [SwipeCellAction]? {
        if configuration.presentationOrigin == .activities || listStyle == .grid {
            return nil
        }
        var actions = [SwipeCellAction]()
        if let file = getFile(at: indexPath) {
            if file.capabilities.canShare {
                actions.append(.share)
            }
            if file.capabilities.canDelete {
                actions.append(.delete)
            }
        }

        return actions
    }

    func forceRefresh() {
        endRefreshing()
        Task {
            try await loadFiles(cursor: nil, forceRefresh: true)
        }
    }

    func loadActivitiesIfNeeded() async throws {
        if currentDirectory.canLoadChildrenFromCache {
            let responseAtDate = Date(timeIntervalSince1970: Double(currentDirectory.responseAt))
            let now = Date()
            if responseAtDate.distance(to: now) > Constants.activitiesReloadTimeOut {
                try await loadFiles(cursor: nil, forceRefresh: true)
            } else {
                try await loadActivities()
            }
        }
    }

    // MARK: - Sort options delegate

    func didSelect(option: Selectable) {
        guard let type = option as? SortType else { return }
        MatomoUtils.track(eventWithCategory: .fileList, name: "sort-\(type.rawValue)")
        FileListOptions.instance.currentSortType = type
    }
}

extension Publisher where Self.Failure == Never {
    func assignNoRetain<Root>(to keyPath: ReferenceWritableKeyPath<Root, Self.Output>, on object: Root) -> AnyCancellable
        where Root: AnyObject {
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

extension AnyRealmCollection {
    func filesSorted(by sortType: SortType) -> Results<Element> {
        return sorted(by: [
            SortDescriptor(keyPath: \File.type, ascending: true),
            SortDescriptor(keyPath: \File.visibility, ascending: false),
            sortType.value.sortDescriptor
        ])
    }
}
