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
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import SafariServices
import UIKit
import VersionChecker

final class SceneDelegate: UIResponder, UIWindowSceneDelegate, AccountManagerDelegate {
    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var lockHelper: AppLockHelper
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var driveInfosManager: DriveInfosManager
    @LazyInjectService var backgroundTasksService: BackgroundTasksServiceable
    @LazyInjectService var appNavigable: AppNavigable
    @LazyInjectService var appRestorationService: AppRestorationServiceable
    @LazyInjectService var deeplinkParser: DeeplinkParsable
    @LazyInjectService var uploadNotifications: UploadNotifiable
    @LazyInjectService var uploadDataSource: UploadServiceDataSourceable
    @LazyInjectService var uploadObservation: UploadObservable

    private var mediaHelper: OpenMediaHelper?
    var shortcutItemToProcess: UIApplicationShortcutItem?

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        Log.sceneDelegate("scene session options")
        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }

        if let shortcutItem = connectionOptions.shortcutItem {
            shortcutItemToProcess = shortcutItem
        }

        prepareWindowScene(windowScene)

        accountManager.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDrive), name: .reloadDrive, object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocateUploadNotification),
            name: .locateUploadActionTapped,
            object: nil
        )

        let isRestoration: Bool = session.stateRestorationActivity != nil
        Log.sceneDelegate("user activity isRestoration:\(isRestoration) \(String(describing: session.stateRestorationActivity))")

        guard let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity else {
            Log.sceneDelegate("no user activity")
            return
        }

        Task {
            guard await !continueWebActivityIfPossible(scene, userActivity: userActivity) else {
                return
            }

            guard userActivity.activityType == SceneActivityIdentifier.mainSceneActivityType else {
                Log.sceneDelegate("unsupported user activity type:\(userActivity.activityType)")
                return
            }

            scene.userActivity = userActivity

            guard let userInfo = userActivity.userInfo else {
                Log.sceneDelegate("activity has no metadata to process")
                return
            }

            Log.sceneDelegate("restore from \(userActivity.activityType)")
            Log.sceneDelegate("selectedIndex:\(String(describing: userInfo[SceneRestorationKeys.selectedIndex.rawValue]))")
        }
    }

    private func prepareWindowScene(_ windowScene: UIWindowScene) {
        let newWindow = UIWindow(windowScene: windowScene)

        window = newWindow
        newWindow.makeKeyAndVisible()

        setGlobalWindowTint()
        appNavigable.updateTheme()
    }

    func configure(window: UIWindow?, session: UISceneSession, with activity: NSUserActivity) -> Bool {
        Log.sceneDelegate("configure session with")
        return true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        Log.sceneDelegate("sceneDidDisconnect \(scene)")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        Log.sceneDelegate("sceneWillResignActive \(scene)")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        Log.sceneDelegate("sceneWillEnterForeground \(scene) \(String(describing: window))")
        if window?.rootViewController == nil {
            appNavigable.prepareRootViewController(currentState: .splashScreen, restoration: false)

            Task {
                await TokenMigrator().migrateTokensIfNeeded()
                await UserProfileMigrator().migrateUserProfilesIfNeeded()

                finishSceneSetup(scene, skipRestoration: false)
            }
        } else {
            finishSceneSetup(scene, skipRestoration: true)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Log.sceneDelegate("sceneDidBecomeActive \(scene)")
        mediaHelper = nil

        guard let shortcutItem = shortcutItemToProcess else {
            return
        }

        guard let viewController = appNavigable.getCurrentController() else {
            return
        }

        viewController.dismiss(animated: false)

        guard let driveFileManager = accountManager.currentDriveFileManager else {
            return
        }

        switch shortcutItem.type {
        case Constants.applicationShortcutScan:
            let openMediaHelper = OpenMediaHelper(driveFileManager: driveFileManager)
            openMediaHelper.openScan(viewController, false)
            mediaHelper = openMediaHelper
            matomo.track(eventWithCategory: .shortcuts, name: "scan")
        case Constants.applicationShortcutSearch:
            let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager)
            viewController.present(
                SearchViewController.instantiateInNavigationController(viewModel: viewModel),
                animated: true
            )
            matomo.track(eventWithCategory: .shortcuts, name: "search")
        case Constants.applicationShortcutUpload:
            let openMediaHelper = OpenMediaHelper(driveFileManager: driveFileManager)
            openMediaHelper.openMedia(viewController, .library)
            mediaHelper = openMediaHelper
            matomo.track(eventWithCategory: .shortcuts, name: "upload")
        case Constants.applicationShortcutSupport:
            UIApplication.shared.open(URLConstants.support.url)
            matomo.track(eventWithCategory: .shortcuts, name: "support")
        default:
            break
        }

        shortcutItemToProcess = nil
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        Log.sceneDelegate("sceneDidEnterBackground \(scene)")

        backgroundTasksService.scheduleBackgroundRefresh()

        if UserDefaults.shared.isAppLockEnabled,
           !(window?.rootViewController?.isKind(of: LockedAppViewController.self) ?? false) {
            lockHelper.setTime()
        }
    }

    // MARK: - Window Scene

    func windowScene(_ windowScene: UIWindowScene,
                     didUpdate previousCoordinateSpace: UICoordinateSpace,
                     interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
                     traitCollection previousTraitCollection: UITraitCollection) {
        Log.sceneDelegate("windowScene didUpdate")
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem) async -> Bool {
        Log.sceneDelegate("windowScene performActionFor :\(shortcutItem)")
        shortcutItemToProcess = shortcutItem
        return true
    }

    // MARK: - Deeplink

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            Log.sceneDelegate("scene unable to navigate to url", level: .error)
            return
        }

        Task {
            let success = await deeplinkParser.parse(url: url)
            Log.sceneDelegate("scene open url: \(url) success: \(success)")
        }
    }

    @discardableResult
    private func continueWebActivityIfPossible(_ scene: UIScene, userActivity: NSUserActivity) async -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL else {
            Log.sceneDelegate("the scene continue userActivity - is not NSUserActivityTypeBrowsingWeb", level: .error)
            return false
        }

        return await deeplinkParser.parse(url: incomingURL)
    }

    // MARK: - Handoff support

    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
        Log.sceneDelegate("scene willContinueUserActivityWithType")
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        Log.sceneDelegate("scene continue userActivity")
        Task {
            await continueWebActivityIfPossible(scene, userActivity: userActivity)
        }
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
    @MainActor func finishSceneSetup(_ scene: UIScene, skipRestoration: Bool) {
        uploadNotifications.setPausedNotificationSent(false)

        let currentState = RootViewControllerState.getCurrentState()
        let session = scene.session
        let isRestoration: Bool = session.stateRestorationActivity != nil
        Log.sceneDelegate("user activity isRestoration:\(isRestoration) \(String(describing: session.stateRestorationActivity))")
        if !skipRestoration {
            appNavigable.prepareRootViewController(currentState: currentState, restoration: isRestoration)
        }

        switch currentState {
        case .mainViewController, .appLock:
            UserDefaults.shared.numberOfConnections += 1
            if UserDefaults.shared.object(forKey: "actionUntilReview") != nil {
                UserDefaults.shared.actionUntilReview -= 1
            }
            Task {
                await appNavigable.refreshCacheScanLibraryAndUpload(preload: false, isSwitching: false)
            }
            uploadEditedFiles()
        case .splashScreen, .onboarding, .updateRequired, .preloading: break
        }

        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        Task {
            await InAppTwoFactorAuthenticationHelper().checkTwoFAChallenges()
        }

        Task {
            if try await VersionChecker.standard.checkAppVersionStatus() == .updateIsRequired {
                appNavigable.prepareRootViewController(currentState: .updateRequired, restoration: false)
            }
        }
    }

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
            let driveFolderURL = folderURL.appendingPathComponent(driveFolder)
            guard let driveId = Int(driveFolder),
                  let drive = driveInfosManager.getDrive(id: driveId, userId: accountManager.currentUserId),
                  let fileFolders = try? FileManager.default.contentsOfDirectory(atPath: driveFolderURL.path) else {
                Log.sceneDelegate("[OPEN-IN-PLACE UPLOAD] Could not infer drive from \(driveFolderURL)")
                continue
            }

            for fileFolder in fileFolders {
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

                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let modificationDate = attributes?[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0)

                guard modificationDate > file.revisedAt else {
                    continue
                }

                let uploadFile = UploadFile(parentDirectoryId: file.parentId,
                                            userId: accountManager.currentUserId,
                                            driveId: file.driveId,
                                            url: fileURL,
                                            name: file.name,
                                            conflictOption: .version,
                                            shouldRemoveAfterUpload: false)
                group.enter()
                shouldCleanFolder = true
                var observationToken: ObservationToken?
                observationToken = uploadObservation
                    .observeFileUploaded(self, fileId: uploadFile.id) { [fileId = file.id] uploadFile, _ in
                        observationToken?.cancel()
                        if let error = uploadFile.error {
                            shouldCleanFolder = false
                            Log.sceneDelegate("[OPEN-IN-PLACE UPLOAD] Error while uploading: \(error)", level: .error)
                        } else {
                            // Update file to get the new modification date
                            Task {
                                let file = try await driveFileManager.file(
                                    ProxyFile(driveId: driveFileManager.driveId, id: fileId),
                                    forceRefresh: true
                                )
                                try? FileManager.default.setAttributes([.modificationDate: file.revisedAt],
                                                                       ofItemAtPath: file.localUrl.path)
                                driveFileManager.notifyObserversWith(file: file)
                            }
                        }
                        group.leave()
                    }
                uploadDataSource.saveToRealm(uploadFile, itemIdentifier: nil, addToQueue: true)
            }
        }

        group.notify(queue: DispatchQueue.global(qos: .utility)) {
            if shouldCleanFolder {
                Log.sceneDelegate("[OPEN-IN-PLACE UPLOAD] Cleaning folder")
                try? FileManager.default.removeItem(at: folderURL)
            }
        }
    }

    private func setGlobalWindowTint() {
        window?.tintColor = KDriveResourcesAsset.infomaniakColor.color
        UITabBar.appearance().unselectedItemTintColor = KDriveResourcesAsset.iconColor.color

        // Migration from old UserDefaults
        if UserDefaults.shared.legacyIsFirstLaunch {
            UserDefaults.shared.legacyIsFirstLaunch = UserDefaults.standard.legacyIsFirstLaunch
        }
    }
}

extension SceneDelegate {
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        Log.sceneDelegate("stateRestorationActivity for:\(scene)")
        guard appRestorationService.shouldRestoreApplicationState else {
            return nil
        }

        return scene.userActivity
    }
}
