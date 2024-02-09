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
import InfomaniakCoreUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

// MARK: - FooterButtonDelegate

extension SaveFileViewController: FooterButtonDelegate {
    @objc func didClickOnButton(_ sender: AnyObject) {
        guard let drive = selectedDriveFileManager?.drive,
              let directory = selectedDirectory else {
            return
        }

        // Making sure the user cannot spam the button on tasks that may take a while
        let button = sender as? IKLargeButton
        button?.setLoading(true)

        let items = items
        guard !items.isEmpty else {
            dismiss(animated: true)
            return
        }

        Task {
            await presentSnackBarSaveAndDismiss(files: items, directory: directory, drive: drive)
        }
    }

    private func presentSnackBarSaveAndDismiss(files: [ImportedFile], directory: File, drive: Drive) async {
        let message: String
        do {
            try await processForUpload(files: files, directory: directory, drive: drive)

            message = files.count > 1 ? KDriveResourcesStrings.Localizable
                .allUploadInProgressPlural(files.count) : KDriveResourcesStrings.Localizable
                .allUploadInProgress(files[0].name)
        } catch {
            message = error.localizedDescription
        }

        Task { @MainActor in
            self.dismiss(animated: true, clean: false) {
                UIConstants.showSnackBar(message: message)
            }
        }
    }

    private func processForUpload(files: [ImportedFile], directory: File, drive: Drive) async throws {
        // We only schedule for uploading in main app target
        let addToQueue = !Bundle.main.isExtension
        try await fileImportHelper.saveForUpload(files, in: directory, drive: drive, addToQueue: addToQueue)
        #if ISEXTENSION
        showOpenAppToContinueNotification()
        #endif
    }

    #if ISEXTENSION
    //  Dynamic hook to open an URL within an extension
    @objc func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                return application.perform(#selector(openURL(_:)), with: url) != nil
            }
            responder = responder?.next
        }
        return false
    }

    func showOpenAppToContinueNotification() {
        guard openURL(URLConstants.kDriveRedirection.url) else {
            // Fallback on a local notification if failure to open URL
            @InjectService var notificationHelper: NotificationsHelpable
            notificationHelper.sendPausedUploadQueueNotification()
            return
        }
    }
    #endif
}
