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

import Foundation
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import kDriveResources
import StoreKit
import UIKit

extension AppDelegate {
    // MARK: Launch

    func launchSetup() {
        // Simulating a "background foreground" if requested
        guard !Self.simulateLongRunningSession else {
            launchSetupSimulateBackground()
            return
        }

        // Change app tint
        setGlobalTint()

        @InjectService var accountManager: AccountManageable
        if UserDefaults.shared.legacyIsFirstLaunch || accountManager.accounts.isEmpty {
            showOnboarding()
        } else if UserDefaults.shared.isAppLockEnabled && lockHelper.isAppLocked {
            showAppLock()
        } else if let driveFileManager = accountManager.currentDriveFileManager {
            showMainViewController(driveFileManager: driveFileManager)
            UserDefaults.shared.numberOfConnections += 1

            // Show launch floating panel
            showLaunchFloatingPanel()

            // Request App Store review
            requestAppStoreReview()

            // Refresh data
            refreshCacheData(preload: false, isSwitching: false)

            // Upload edited files
            uploadEditedFiles()

            // Ask to remove uploaded pictures
            askUserToRemovePicturesIfNecessary()
        } else {
            // Default to show onboarding
            showOnboarding()
        }
    }

    private func launchSetupSimulateBackground() {
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()

        Log.appDelegate("handleBackgroundRefresh begin")
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + 0.5) {
            self.handleBackgroundRefresh { success in
                Log.appDelegate("handleBackgroundRefresh success:\(success)")
            }
        }
    }

    // MARK: Set root VC

    func showMainViewController(driveFileManager: DriveFileManager) {
        guard let window else {
            return
        }

        let currentDriveObjectId = (window.rootViewController as? MainTabViewController)?.driveFileManager.drive.objectId
        guard currentDriveObjectId != driveFileManager.drive.objectId else {
            return
        }

        window.rootViewController = MainTabViewController(driveFileManager: driveFileManager)
        window.makeKeyAndVisible()
    }

    private func showOnboarding() {
        guard let window else {
            return
        }

        defer {
            // Clean File Provider domains on first launch in case we had some dangling
            DriveInfosManager.instance.deleteAllFileProviderDomains()
        }

        // Check if presenting onboarding
        let isNotPresentingOnboarding = window.rootViewController?.isKind(of: OnboardingViewController.self) != true
        guard isNotPresentingOnboarding else {
            return
        }

        KeychainHelper.deleteAllTokens()
        window.rootViewController = OnboardingViewController.instantiate()
        window.makeKeyAndVisible()
    }

    private func showAppLock() {
        guard let window else {
            return
        }

        window.rootViewController = LockedAppViewController.instantiate()
        window.makeKeyAndVisible()
    }

    private func showLaunchFloatingPanel() {
        guard let window else {
            return
        }

        let launchPanelsController = LaunchPanelsController()
        if let viewController = window.rootViewController {
            launchPanelsController.pickAndDisplayPanel(viewController: viewController)
        }
    }

    // MARK: Misc

    private func requestAppStoreReview() {
        guard UserDefaults.shared.numberOfConnections == 10 else {
            return
        }

        if #available(iOS 14.0, *) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        } else {
            SKStoreReviewController.requestReview()
        }
    }

    /// Set global tint color
    private func setGlobalTint() {
        window?.tintColor = KDriveResourcesAsset.infomaniakColor.color
        UITabBar.appearance().unselectedItemTintColor = KDriveResourcesAsset.iconColor.color
        // Migration from old UserDefaults
        if UserDefaults.shared.legacyIsFirstLaunch {
            UserDefaults.shared.legacyIsFirstLaunch = UserDefaults.standard.legacyIsFirstLaunch
        }
    }

    // TODO: Refactor to async
    private func uploadEditedFiles() {
        Log.appDelegate("uploadEditedFiles")
        guard let folderURL = DriveFileManager.constants.openInPlaceDirectoryURL,
              FileManager.default.fileExists(atPath: folderURL.path) else {
            return
        }

        @InjectService var accountManager: AccountManageable
        let group = DispatchGroup()
        var shouldCleanFolder = false
        let driveFolders = (try? FileManager.default.contentsOfDirectory(atPath: folderURL.path)) ?? []
        // Hierarchy inside folderURL should be /driveId/fileId/fileName.extension
        for driveFolder in driveFolders {
            // Read drive folder
            let driveFolderURL = folderURL.appendingPathComponent(driveFolder)
            guard let driveId = Int(driveFolder),
                  let drive = DriveInfosManager.instance.getDrive(id: driveId, userId: accountManager.currentUserId),
                  let fileFolders = try? FileManager.default.contentsOfDirectory(atPath: driveFolderURL.path) else {
                Log.appDelegate("[OPEN-IN-PLACE UPLOAD] Could not infer drive from \(driveFolderURL)")
                continue
            }

            for fileFolder in fileFolders {
                // Read file folder
                let fileFolderURL = driveFolderURL.appendingPathComponent(fileFolder)
                guard let fileId = Int(fileFolder),
                      let driveFileManager = accountManager.getDriveFileManager(for: drive),
                      let file = driveFileManager.getCachedFile(id: fileId) else {
                    Log.appDelegate("[OPEN-IN-PLACE UPLOAD] Could not infer file from \(fileFolderURL)")
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
                                            driveId: driveId,
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
                            Log.appDelegate("[OPEN-IN-PLACE UPLOAD] Error while uploading: \(error)", level: .error)
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
                uploadQueue.saveToRealmAndAddToQueue(uploadFile: uploadFile, itemIdentifier: nil)
            }
        }

        // Clean folder after completing all uploads
        group.notify(queue: DispatchQueue.global(qos: .utility)) {
            if shouldCleanFolder {
                Log.appDelegate("[OPEN-IN-PLACE UPLOAD] Cleaning folder")
                try? FileManager.default.removeItem(at: folderURL)
            }
        }
    }

    /// Ask the user to remove pictures if configured
    private func askUserToRemovePicturesIfNecessary() {
        guard let toRemoveItems = photoLibraryUploader.getPicturesToRemove() else {
            return
        }

        let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalDeletePhotosTitle,
                                            message: KDriveResourcesStrings.Localizable.modalDeletePhotosDescription,
                                            action: KDriveResourcesStrings.Localizable.buttonDelete,
                                            destructive: true,
                                            loading: false) {
            // Proceed with removal
            self.photoLibraryUploader.removePicturesFromPhotoLibrary(toRemoveItems)
        }

        Task { @MainActor in
            self.window?.rootViewController?.present(alert, animated: true)
        }
    }
}
