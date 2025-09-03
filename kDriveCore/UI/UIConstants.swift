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

import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveResources
import KSuite
import LinkPresentation
import SnackBar
import UIKit

public enum UIConstants {
    public enum Padding {
        public static let none: CGFloat = 0.0
        public static let small: CGFloat = 8.0
        public static let mediumSmall: CGFloat = 12.0
        public static let medium: CGFloat = 16.0
        public static let standard: CGFloat = 24.0
    }

    public enum Button {
        public static let largeHeight: CGFloat = 60.0
        public static let cornerRadius = 10.0
        public static let profileImageSize: CGFloat = 32.0
    }

    public enum List {
        public static let paddingBottom = 50.0
        public static let publicSharePaddingBottom = 90.0
        public static let floatingButtonPaddingBottom = 75.0
    }

    public enum FloatingPanel {
        public static let cornerRadius = 20.0
        public static let headerHeight = 70.0
    }

    public enum Image {
        public static let cornerRadius = 3.0
    }

    public enum Alert {
        public static let cornerRadius = 8.0
    }

    public enum FileList {
        public static let cellHeight = 60.0
    }

    private static let style: SnackBarStyle = {
        var style = SnackBarStyle.infomaniakStyle
        style.anchor = 20.0
        style.maxWidth = 600.0
        return style
    }()

    public static let cornerRadius = 6.0
    public static let largeTitleHeight = 96.0
    public static let insufficientStorageMinimumPercentage = 90.0
    public static let dropDelay = -1.0
}

public extension UIConstants {
    @discardableResult
    @MainActor
    static func showSnackBar(message: String,
                             duration: SnackBar.Duration = .lengthLong,
                             action: IKSnackBar.Action? = nil) -> IKSnackBar? {
        let snackbar = IKSnackBar.make(message: message,
                                       duration: duration,
                                       style: style)
        if let action {
            snackbar?.setAction(action).show()
        } else {
            snackbar?.show()
        }
        return snackbar
    }

    @discardableResult
    @MainActor
    static func showCancelableSnackBar(
        message: String,
        cancelSuccessMessage: String,
        duration: SnackBar.Duration = .lengthLong,
        cancelableResponse: CancelableResponse,
        parentFile: ProxyFile?,
        driveFileManager: DriveFileManager
    ) -> IKSnackBar? {
        return UIConstants.showSnackBar(
            message: message,
            duration: duration,
            action: .init(title: KDriveResourcesStrings.Localizable.buttonCancel) {
                Task {
                    do {
                        try await driveFileManager.undoAction(cancelId: cancelableResponse.id)
                        if let parentFile {
                            _ = try? await driveFileManager.fileActivities(file: parentFile)
                        }

                        UIConstants.showSnackBar(message: cancelSuccessMessage)
                    } catch {
                        UIConstants.showSnackBarIfNeeded(error: error)
                    }
                }
            }
        )
    }

    @MainActor
    static func showSnackBarIfNeeded(error: Error) {
        if (ReachabilityListener.instance.currentStatus == .offline || ReachabilityListener.instance.currentStatus == .undefined)
            && (error.asAFError?.isRequestAdaptationError == true || error.asAFError?.isSessionTaskError == true) {
            // No network and refresh token failed
        } else if error.asAFError?.isExplicitlyCancelledError == true || (error as? DriveError) == .searchCancelled {
            // User cancelled the request
        } else if (error as? DriveError) == .taskCancelled || (error as? DriveError) == .taskRescheduled {
            // Task was rescheduled
        } else {
            @InjectService var accountManager: AccountManageable
            guard let driveError = error as? DriveError,
                  driveError == DriveError.errorDeviceStorage,
                  let currentDriveFileManager = accountManager.currentDriveFileManager,
                  currentDriveFileManager.drive.pack.drivePackId == .kSuiteEssential else {
                UIConstants.showSnackBar(message: error.localizedDescription)
                return
            }

            let title = KSuiteLocalizable.kSuiteUpgradeButton.capitalizingFirstLetterOnly
            let upgradeAction = IKSnackBar.Action(title: title) {
                @InjectService var router: AppNavigable
                router.presentKDriveProUpSaleSheet(driveFileManager: currentDriveFileManager)
            }

            UIConstants.showSnackBar(message: error.localizedDescription, action: upgradeAction)
        }
    }

    static func openUrl(_ string: String, from viewController: UIViewController) {
        if let url = URL(string: string) {
            openUrl(url, from: viewController)
        }
    }

    static func openUrl(_ url: URL, from viewController: UIViewController) {
        #if ISEXTENSION
        viewController.extensionContext?.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    static func presentLinkPreviewForFile(
        _ file: File,
        link: String,
        from viewController: UIViewController,
        sourceView: UIView
    ) {
        guard let url = URL(string: link) else { return }
        createLinkPreviewForFile(file, link: url) { linkPreviewMetadata in
            let activityViewController = UIActivityViewController(
                activityItems: [ShareLinkPreviewDelegate(shareSheetLinkMetadata: linkPreviewMetadata)],
                applicationActivities: nil
            )
            activityViewController.popoverPresentationController?.sourceView = sourceView
            viewController.present(activityViewController, animated: true)
        }
    }

    private static func createLinkPreviewForFile(_ file: File, link: URL, completion: @escaping (LPLinkMetadata) -> Void) {
        if ConvertedType.ignoreThumbnailTypes.contains(file.convertedType) || !file.supportedBy.contains(.thumbnail) {
            completion(createLinkMetadata(file: file, url: link, thumbnail: file.icon))
        } else {
            file.getThumbnail { thumbnail, _ in
                completion(createLinkMetadata(file: file, url: link, thumbnail: thumbnail))
            }
        }
    }

    private static func createLinkMetadata(file: File, url: URL, thumbnail: UIImage) -> LPLinkMetadata {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = metadata.originalURL

        let title: String
        if file.isDropbox {
            title = KDriveResourcesStrings.Localizable.buttonShareDropboxLink
        } else if file.sharelink == nil {
            title = KDriveResourcesStrings.Localizable.buttonSharePrivateLink
        } else {
            title = KDriveResourcesStrings.Localizable.buttonSharePublicLink
        }

        metadata.title = title
        metadata.iconProvider = NSItemProvider(object: thumbnail)

        return metadata
    }
}

private class ShareLinkPreviewDelegate: NSObject, UIActivityItemSource {
    private var shareSheetLinkMetadata: LPLinkMetadata

    init(shareSheetLinkMetadata: LPLinkMetadata) {
        self.shareSheetLinkMetadata = shareSheetLinkMetadata
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        // We force unwrap because URL is safe and created before
        return shareSheetLinkMetadata.url!
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        return shareSheetLinkMetadata.url
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        return shareSheetLinkMetadata
    }
}
