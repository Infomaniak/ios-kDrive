/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

extension SaveFileViewController: FooterButtonDelegate {
    @objc func didClickOnButton(_ sender: AnyObject) {
        guard let selectedDriveFileManager,
              let directory = selectedDirectory else {
            return
        }
        let drive = selectedDriveFileManager.drive
        let button = sender as? IKLargeButton
        button?.setLoading(true)

        guard let publicShareProxy else {
            guard !items.isEmpty else {
                dismissViewController()
                return
            }

            Task {
                await saveAndDismiss(files: items, directory: directory, drive: drive)
            }
            return
        }

        Task {
            defer { dismissViewController() }
            try await savePublicShareToDrive(sourceDriveId: publicShareProxy.driveId,
                                             destinationDriveId: drive.id,
                                             destinationFolderId: directory.id,
                                             fileIds: publicShareFileIds,
                                             exceptIds: publicShareExceptIds,
                                             sharelinkUuid: publicShareProxy.shareLinkUid,
                                             driveFileManager: selectedDriveFileManager)
        }
    }

    private func savePublicShareToDrive(sourceDriveId: Int,
                                        destinationDriveId: Int,
                                        destinationFolderId: Int,
                                        fileIds: [Int],
                                        exceptIds: [Int],
                                        sharelinkUuid: String,
                                        driveFileManager: DriveFileManager) async throws {
        try await _ = driveFileManager.apiFetcher.importShareLinkFiles(sourceDriveId: sourceDriveId,
                                                                       destinationDriveId: destinationDriveId,
                                                                       destinationFolderId: destinationFolderId,
                                                                       fileIds: fileIds,
                                                                       exceptIds: exceptIds,
                                                                       sharelinkUuid: sharelinkUuid)
    }

    private func dismissViewController() {
        onDismissViewController?()
        dismiss(animated: true)
    }

    private func saveAndDismiss(files: [ImportedFile], directory: File, drive: Drive) async {
        let message: String
        do {
            try await processForUpload(files: files, directory: directory, drive: drive)

            message = files.count > 1 ? KDriveResourcesStrings.Localizable
                .allUploadInProgressPlural(files.count) : KDriveResourcesStrings.Localizable
                .allUploadInProgress(files[0].name)
        } catch {
            message = error.localizedDescription
        }

        presentSnackBar(message)
    }

    private func presentSnackBar(_ message: String) {
        Task { @MainActor in
            self.dismiss(animated: true, clean: false) {
                UIConstants.showSnackBar(message: message)
            }
        }
    }

    private func processForUpload(files: [ImportedFile], directory: File, drive: Drive) async throws {
        // We only schedule for uploading in main app target
        let addToQueue = !appContextService.isExtension
        try await fileImportHelper.saveForUpload(files, in: directory, drive: drive, addToQueue: addToQueue)
        #if ISEXTENSION
        await showOpenAppToContinueNotification()
        #endif
    }

    #if ISEXTENSION
    //  Dynamic hook to open an URL within an extension
    func openURL(_ url: URL) async -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                return await application.open(url)
            }
            responder = responder?.next
        }
        return false
    }

    func showOpenAppToContinueNotification() async {
        guard await openURL(URLConstants.kDriveRedirection.url) else {
            // Fallback on a local notification if failure to open URL
            @InjectService var notificationHelper: NotificationsHelpable
            notificationHelper.sendPausedUploadQueueNotification()
            return
        }
    }
    #endif
}
