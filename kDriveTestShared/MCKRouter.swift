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
import InfomaniakLogin
import kDrive
import kDriveCore
import UIKit

/// A NOOP implementation of AppNavigable
public final class MCKRouter: AppNavigable {
    public var rootViewController: UIViewController?

    public init(topMostViewController: UIViewController? = nil) {
        self.topMostViewController = topMostViewController
    }

    private func logNoop(function: String = #function) {
        print("MCKRouter: NOOP \(function) called")
    }

    public func askForNotificationPermission() async {
        logNoop()
    }

    public func navigate(to route: NavigationRoutes) {
        logNoop()
    }

    public func askForReview() async {
        logNoop()
    }

    public func presentAccountViewController(navigationController: UINavigationController, animated: Bool) {
        logNoop()
    }

    public func askUserToRemovePicturesIfNecessary() async {
        logNoop()
    }

    public func askUserToRemovePicturesIfNecessaryNotification() async {
        logNoop()
    }

    public func presentUpSaleSheet() {
        logNoop()
    }

    public func presentKDriveProUpSaleSheet(driveFileManager: kDriveCore.DriveFileManager) {
        logNoop()
    }

    public func refreshCacheScanLibraryAndUpload(preload: Bool, isSwitching: Bool) async {
        logNoop()
    }

    public func showMainViewController(driveFileManager: kDriveCore.DriveFileManager,
                                       selectedIndex: Int?) -> UISplitViewController? {
        logNoop()
        return nil
    }

    public func showPreloading(currentAccount: InfomaniakCore.Account) {
        logNoop()
    }

    public func showOnboarding() {
        logNoop()
    }

    public func showAppLock() {
        logNoop()
    }

    public func showLaunchFloatingPanel() {
        logNoop()
    }

    public func showUpsaleFloatingPanel() {
        logNoop()
    }

    public func showUpdateRequired() {
        logNoop()
    }

    public func showPhotoSyncSettings() {
        logNoop()
    }

    public func showLogin(delegate: InfomaniakLoginDelegate) {
        logNoop()
    }

    public func showRegister(delegate: InfomaniakLoginDelegate) {
        logNoop()
    }

    public func present(file: kDriveCore.File, driveFileManager: kDriveCore.DriveFileManager) {
        logNoop()
    }

    public func present(file: kDriveCore.File, driveFileManager: kDriveCore.DriveFileManager, office: Bool) {
        logNoop()
    }

    public func presentFileList(
        frozenFolder: kDriveCore.File,
        driveFileManager: kDriveCore.DriveFileManager,
        navigationController: UINavigationController
    ) {
        logNoop()
    }

    public func presentPreviewViewController(
        frozenFiles: [kDriveCore.File],
        index: Int,
        driveFileManager: kDriveCore.DriveFileManager,
        normalFolderHierarchy: Bool,
        presentationOrigin: PresentationOrigin,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        logNoop()
    }

    public func presentFileDetails(
        frozenFile: kDriveCore.File,
        driveFileManager: kDriveCore.DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        logNoop()
    }

    public func presentStoreViewController(
        driveFileManager: kDriveCore.DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        logNoop()
    }

    public func presentOnlyOfficeViewController(
        driveFileManager: DriveFileManager,
        file: File,
        viewController: UIViewController
    ) {
        logNoop()
    }

    public func setRootViewController(_ viewController: UIViewController, animated: Bool) {
        logNoop()
    }

    public func prepareRootViewController(currentState: RootViewControllerState, restoration: Bool) {
        logNoop()
    }

    public func updateTheme() {
        logNoop()
    }

    public var topMostViewController: UIViewController?

    public func showStore(from viewController: UIViewController, driveFileManager: DriveFileManager) {
        logNoop()
    }

    public func showSaveFileVC(from viewController: UIViewController, driveFileManager: DriveFileManager, files: [ImportedFile]) {
        logNoop()
    }

    @MainActor public func presentPublicShareLocked(_ destinationURL: URL) {
        logNoop()
    }

    @MainActor public func presentPublicShareExpired() {
        logNoop()
    }

    @MainActor public func presentPublicShare(
        frozenRootFolder: File,
        publicShareProxy: PublicShareProxy,
        driveFileManager: DriveFileManager,
        apiFetcher: PublicShareApiFetcher
    ) {
        logNoop()
    }

    @MainActor public func presentPublicShare(
        singleFrozenFile: File,
        virtualFrozenRootFolder: File,
        publicShareProxy: PublicShareProxy,
        driveFileManager: DriveFileManager,
        apiFetcher: PublicShareApiFetcher
    ) {
        logNoop()
    }

    public func presentUploadViewController(
        driveFileManager: kDriveCore.DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        logNoop()
    }

    public func getCurrentController() -> UIViewController? {
        logNoop()
        return nil
    }

    public func askUserToRemovePicturesIfNecessaryNotification() {
        logNoop()
    }
}
