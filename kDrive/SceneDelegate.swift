/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import InfomaniakCore
import InfomaniakCoreUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import SafariServices
import UIKit
import VersionChecker

public protocol SceneStateRestorable {
    func saveSceneState()
}

enum SceneRestorationKeys: String {
    /// The selected index of the MainViewController that should be restored
    case selectedIndex

    /// Array representing the stack of view controllers that should be restored
    // TODO: Implement stack restoration
    // case fileViewStack

    /// The screen that should be restored on top of the MainViewController
    case lastViewController
}

// TODO: Namespace by screen
enum SceneRestorationValues: String {
    case DriveId
    case FileId

    // PreviewVC
    case FilesIds
    case currentIndex
    case normalFolderHierarchy
    case fromActivities
}

/// ViewController identifiers for state restoration
enum SceneRestorationScreens: String {
    /// Preview a file
    case PreviewViewController

    /// Metadata of the file
    case FileDetailViewController

    /// File listing view
    case FileListViewController

    /// InApp purchase
    case StoreViewController
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate, AccountManagerDelegate {
    @LazyInjectService var lockHelper: AppLockHelper
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var driveInfosManager: DriveInfosManager
    @LazyInjectService var backgroundTasksService: BackgroundTasksServiceable
    @LazyInjectService var appNavigable: AppNavigable
    @LazyInjectService var appRestorationService: AppRestorationServiceable

    // TODO: Abstract away from AppDelegate
    private var shortcutItemToProcess: UIApplicationShortcutItem? {
        get {
            (UIApplication.shared.delegate as? AppDelegate)?.shortcutItemToProcess
        }
        set {
            (UIApplication.shared.delegate as? AppDelegate)?.shortcutItemToProcess = newValue
        }
    }

    var window: UIWindow?

    /** Apps configure their UIWindow and attach it to the provided UIWindowScene scene.
         The system calls willConnectTo shortly after the app delegate's "configurationForConnecting" function.
         Use this function to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.

         When using a storyboard file, as specified by the Info.plist key, UISceneStoryboardFile, the system automatically configures
         the window property and attaches it to the windowScene.

         Remember to retain the SceneDelegate's UIWindow.
         The recommended approach is for the SceneDelegate to retain the scene's window.
     */
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        Log.sceneDelegate("scene session options")
        /// 1. Capture the scene
        guard let windowScene = (scene as? UIWindowScene) else { return }

        prepareWindowScene(windowScene)

        // Setup accountManager delegation after the window setup like previously in app delegate
        accountManager.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDrive), name: .reloadDrive, object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocateUploadNotification),
            name: .locateUploadActionTapped,
            object: nil
        )

        // Determine the user activity from a new connection or from a session's state restoration.

        let isRestoration: Bool = session.stateRestorationActivity != nil
        Log.sceneDelegate("user activity isRestoration:\(isRestoration) \(session.stateRestorationActivity)")

        guard let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity else {
            Log.sceneDelegate("no user activity")
            return
        }

        guard userActivity.activityType == SceneDelegate.MainSceneActivityType else {
            Log.sceneDelegate("unsupported user activity type:\(userActivity.activityType)")
            return
        }

        // Save activity to new scene
        scene.userActivity = userActivity

        guard let userInfo = userActivity.userInfo else {
            Log.sceneDelegate("activity has no metadata to process")
            return
        }

        Log.sceneDelegate("restore from \(userActivity.activityType)")
        Log.sceneDelegate("selectedIndex:\(userInfo[SceneRestorationKeys.selectedIndex.rawValue])")
    }

    private func prepareWindowScene(_ windowScene: UIWindowScene) {
        // Create a new UIWindow using the windowScene constructor which takes in a window scene.
        let window = UIWindow(windowScene: windowScene)

        // Set the window and call makeKeyAndVisible()
        self.window = window
        window.makeKeyAndVisible()

        // Update tint
        setGlobalWindowTint()
        appNavigable.updateTheme()
    }

    func configure(window: UIWindow?, session: UISceneSession, with activity: NSUserActivity) -> Bool {
        Log.sceneDelegate("configure session with")
        return true
    }

    /** Use this delegate as the system is releasing the scene or on window close.
         This occurs shortly after the scene enters the background, or when the system discards its session.
         Release any scene-related resources that the system can recreate the next time the scene connects.
         The scene may reconnect later because the system didn't necessarily discard its session (see`application:didDiscardSceneSessions` instead),
         so don't delete any user data or state permanently.
     */
    func sceneDidDisconnect(_ scene: UIScene) {
        Log.sceneDelegate("sceneDidDisconnect \(scene)")
    }

    /** Use this delegate when the scene moves from an active state to an inactive state, on window close, or in iOS enter background.
         This may occur due to temporary interruptions (for example, an incoming phone call).
     */
    func sceneWillResignActive(_ scene: UIScene) {
        Log.sceneDelegate("sceneWillResignActive \(scene)")
    }

    /** Use this delegate as the scene transitions from the background to the foreground, on window open, or in iOS resume.
         Use it to undo the changes made on entering the background.
     */
    func sceneWillEnterForeground(_ scene: UIScene) {
        Log.sceneDelegate("sceneWillEnterForeground \(scene) \(window)")
        @InjectService var uploadQueue: UploadQueue
        uploadQueue.pausedNotificationSent = false

        // Set root view here, trying to restore state
        let currentState = RootViewControllerState.getCurrentState()
        let session = scene.session
        let isRestoration: Bool = session.stateRestorationActivity != nil
        Log.sceneDelegate("user activity isRestoration:\(isRestoration) \(session.stateRestorationActivity)")
        appNavigable.prepareRootViewController(currentState: currentState, restoration: isRestoration)

        switch currentState {
        case .mainViewController, .appLock:
            UserDefaults.shared.numberOfConnections += 1
            UserDefaults.shared.openingUntilReview -= 1
            Task {
                await appNavigable.refreshCacheScanLibraryAndUpload(preload: false, isSwitching: false)
            }
            uploadEditedFiles()
        case .onboarding, .updateRequired, .preloading: break
        }

        // Remove all notifications on App Opening
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        Task {
            if try await VersionChecker.standard.checkAppVersionStatus() == .updateIsRequired {
                appNavigable.prepareRootViewController(currentState: .updateRequired, restoration: false)
            }
        }
    }

    /** Use this delegate when the scene "has moved" from an inactive state to an active state.
         Also use it to restart any tasks that the system paused (or didn't start) when the scene was inactive.
         The system calls this delegate every time a scene becomes active so set up your scene UI here.
     */
    func sceneDidBecomeActive(_ scene: UIScene) {
        Log.sceneDelegate("sceneDidBecomeActive \(scene)")
        guard let shortcutItem = shortcutItemToProcess else {
            return
        }

        guard let rootViewController = window?.rootViewController as? MainTabViewController else {
            return
        }

        // Dismiss all view controllers presented
        rootViewController.dismiss(animated: false)

        guard let navController = rootViewController.selectedViewController as? UINavigationController,
              let viewController = navController.topViewController,
              let driveFileManager = accountManager.currentDriveFileManager else {
            return
        }

        switch shortcutItem.type {
        case Constants.applicationShortcutScan:
            let openMediaHelper = OpenMediaHelper(driveFileManager: driveFileManager)
            openMediaHelper.openScan(rootViewController, false)
            MatomoUtils.track(eventWithCategory: .shortcuts, name: "scan")
        case Constants.applicationShortcutSearch:
            let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager)
            viewController.present(
                SearchViewController.instantiateInNavigationController(viewModel: viewModel),
                animated: true
            )
            MatomoUtils.track(eventWithCategory: .shortcuts, name: "search")
        case Constants.applicationShortcutUpload:
            let openMediaHelper = OpenMediaHelper(driveFileManager: driveFileManager)
            openMediaHelper.openMedia(rootViewController, .library)
            MatomoUtils.track(eventWithCategory: .shortcuts, name: "upload")
        case Constants.applicationShortcutSupport:
            UIApplication.shared.open(URLConstants.support.url)
            MatomoUtils.track(eventWithCategory: .shortcuts, name: "support")
        default:
            break
        }

        // reset the shortcut item
        shortcutItemToProcess = nil
    }

    /** Use this delegate as the scene transitions from the foreground to the background.
        Also use it to save data, release shared resources, and store enough scene-specific state information
        to restore the scene to its current state.
     */
    func sceneDidEnterBackground(_ scene: UIScene) {
        Log.sceneDelegate("sceneDidEnterBackground \(scene)")
        backgroundTasksService.scheduleBackgroundRefresh()

        if UserDefaults.shared.isAppLockEnabled,
           !(window?.rootViewController?.isKind(of: LockedAppViewController.self) ?? false) {
            lockHelper.setTime()
        }
    }

    // MARK: - Window Scene

    // Listen for size change.
    func windowScene(_ windowScene: UIWindowScene,
                     didUpdate previousCoordinateSpace: UICoordinateSpace,
                     interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
                     traitCollection previousTraitCollection: UITraitCollection) {
        Log.sceneDelegate("windowScene didUpdate")
    }

    // MARK: - Handoff support

    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
        Log.sceneDelegate("scene willContinueUserActivityWithType")
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        Log.sceneDelegate("scene continue userActivity")
    }

    func scene(_ scene: UIScene, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {
        Log.sceneDelegate("scene didFailToContinueUserActivityWithType")
    }

    // MARK: - Account manager delegate

    func currentAccountNeedsAuthentication() {
        Task { @MainActor in
            let switchUser = SwitchUserViewController.instantiateInNavigationController()
            appNavigable.setRootViewController(switchUser, animated: true)
        }
    }

    // MARK: - Reload drive notification

    @objc func reloadDrive(_ notification: Notification) {
        Task {
            await self.appNavigable.refreshCacheScanLibraryAndUpload(preload: false, isSwitching: false)
        }
    }

    @objc func handleLocateUploadNotification(_ notification: Notification) {
        if let parentId = notification.userInfo?["parentId"] as? Int,
           let driveFileManager = accountManager.currentDriveFileManager,
           let folder = driveFileManager.getCachedFile(id: parentId) {
            appNavigable.present(file: folder, driveFileManager: driveFileManager)
        }
    }
}

// TODO: Refactor with router like pattern and split code away from this class
extension SceneDelegate {
    func uploadEditedFiles() {
        Log.sceneDelegate("uploadEditedFiles")
        guard let folderURL = DriveFileManager.constants.openInPlaceDirectoryURL,
              FileManager.default.fileExists(atPath: folderURL.path) else {
            return
        }

        let group = DispatchGroup()
        var shouldCleanFolder = false
        let driveFolders = (try? FileManager.default.contentsOfDirectory(atPath: folderURL.path)) ?? []
        // Hierarchy inside folderURL should be /driveId/fileId/fileName.extension
        for driveFolder in driveFolders {
            // Read drive folder
            let driveFolderURL = folderURL.appendingPathComponent(driveFolder)
            guard let driveId = Int(driveFolder),
                  let drive = driveInfosManager.getDrive(id: driveId, userId: accountManager.currentUserId),
                  let fileFolders = try? FileManager.default.contentsOfDirectory(atPath: driveFolderURL.path) else {
                Log.sceneDelegate("[OPEN-IN-PLACE UPLOAD] Could not infer drive from \(driveFolderURL)")
                continue
            }

            for fileFolder in fileFolders {
                // Read file folder
                let fileFolderURL = driveFolderURL.appendingPathComponent(fileFolder)
                guard let fileId = Int(fileFolder),
                      let driveFileManager = accountManager.getDriveFileManager(for: drive.id, userId: drive.userId),
                      let file = driveFileManager.getCachedFile(id: fileId) else {
                    Log.sceneDelegate("[OPEN-IN-PLACE UPLOAD] Could not infer file from \(fileFolderURL)")
                    continue
                }

                let fileURL = fileFolderURL.appendingPathComponent(file.name)
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    continue
                }

                // Compare modification date
                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let modificationDate = attributes?[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0)

                guard modificationDate > file.lastModifiedAt else {
                    continue
                }

                // Copy and upload file
                let uploadFile = UploadFile(parentDirectoryId: file.parentId,
                                            userId: accountManager.currentUserId,
                                            driveId: file.driveId,
                                            url: fileURL,
                                            name: file.name,
                                            conflictOption: .version,
                                            shouldRemoveAfterUpload: false)
                group.enter()
                shouldCleanFolder = true
                @InjectService var uploadQueue: UploadQueue
                var observationToken: ObservationToken?
                observationToken = uploadQueue
                    .observeFileUploaded(self, fileId: uploadFile.id) { [fileId = file.id] uploadFile, _ in
                        observationToken?.cancel()
                        if let error = uploadFile.error {
                            shouldCleanFolder = false
                            Log.sceneDelegate("[OPEN-IN-PLACE UPLOAD] Error while uploading: \(error)", level: .error)
                        } else {
                            // Update file to get the new modification date
                            Task {
                                let file = try await driveFileManager.file(id: fileId, forceRefresh: true)
                                try? FileManager.default.setAttributes([.modificationDate: file.lastModifiedAt],
                                                                       ofItemAtPath: file.localUrl.path)
                                driveFileManager.notifyObserversWith(file: file)
                            }
                        }
                        group.leave()
                    }
                uploadQueue.saveToRealm(uploadFile, itemIdentifier: nil)
            }
        }

        // Clean folder after completing all uploads
        group.notify(queue: DispatchQueue.global(qos: .utility)) {
            if shouldCleanFolder {
                Log.sceneDelegate("[OPEN-IN-PLACE UPLOAD] Cleaning folder")
                try? FileManager.default.removeItem(at: folderURL)
            }
        }
    }

    /// Set global tint color
    private func setGlobalWindowTint() {
        window?.tintColor = KDriveResourcesAsset.infomaniakColor.color
        UITabBar.appearance().unselectedItemTintColor = KDriveResourcesAsset.iconColor.color
        // Migration from old UserDefaults
        if UserDefaults.shared.legacyIsFirstLaunch {
            UserDefaults.shared.legacyIsFirstLaunch = UserDefaults.standard.legacyIsFirstLaunch
        }
    }
}

/// Main Scene
extension SceneDelegate {
    /** This is the NSUserActivity that you use to restore state when the Scene reconnects.
        It can be the same activity that you use for handoff or spotlight, or it can be a separate activity
        with a different activity type and/or userInfo.

        This object must be lightweight. You should store the key information about what the user was doing last.

        After the system calls this function, and before it saves the activity in the restoration file, if the returned NSUserActivity has a
        delegate (NSUserActivityDelegate), the function userActivityWillSave calls that delegate. Additionally, if any UIResponders have the activity
        set as their userActivity property, the system calls the UIResponder updateUserActivityState function to update the activity.
        This happens synchronously and ensures that the system has filled in all the information for the activity before saving it.
     */
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        Log.sceneDelegate("stateRestorationActivity for:\(scene)")

        // check if restoration is enabled
        guard appRestorationService.shouldRestoreApplicationState else {
            return nil
        }

        // Offer the user activity for this scene.
        return scene.userActivity
    }

    // Activity type for restoring this scene (loaded from the plist).
    static let MainSceneActivityType: String = {
        // Load the activity type from the Info.plist.
        let activityTypes = Bundle.main.infoDictionary?["NSUserActivityTypes"] as? [String]
        guard let activity = activityTypes?.first else {
            fatalError("Unable to read NSUserActivity config from app plist")
        }

        return activity
    }()
}
