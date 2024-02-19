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
import InfomaniakCoreUI
import kDriveResources
import LinkPresentation
import SnackBar
import UIKit

public enum UIConstants {
    private static let style: SnackBarStyle = {
        var style = SnackBarStyle.infomaniakStyle
        style.anchor = 20.0
        style.maxWidth = 600.0
        return style
    }()

    public static let inputCornerRadius = 2.0
    public static let imageCornerRadius = 3.0
    public static let cornerRadius = 6.0
    public static let alertCornerRadius = 8.0
    public static let buttonCornerRadius = 10.0
    public static let floatingPanelCornerRadius = 20.0
    public static let listPaddingBottom = 50.0
    public static let listFloatingButtonPaddingBottom = 75.0
    public static let homeListPaddingTop = 16.0
    public static let floatingPanelHeaderHeight = 70.0
    public static let fileListCellHeight = 60.0
    public static let largeTitleHeight = 96.0
    public static let insufficientStorageMinimumPercentage = 90.0
    public static let dropDelay = -1.0

    @discardableResult
    @MainActor
    public static func showSnackBar(message: String,
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
    public static func showCancelableSnackBar(
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
                        let now = Date()
                        try await driveFileManager.undoAction(cancelId: cancelableResponse.id)
                        if let parentFile {
                            _ = try? await driveFileManager.fileActivities(file: parentFile, from: Int(now.timeIntervalSince1970))
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
    public static func showSnackBarIfNeeded(error: Error) {
        if (ReachabilityListener.instance.currentStatus == .offline || ReachabilityListener.instance.currentStatus == .undefined)
            && (error.asAFError?.isRequestAdaptationError == true || error.asAFError?.isSessionTaskError == true) {
            // No network and refresh token failed
        } else if error.asAFError?.isExplicitlyCancelledError == true || (error as? DriveError) == .searchCancelled {
            // User cancelled the request
        } else if (error as? DriveError) == .taskCancelled || (error as? DriveError) == .taskRescheduled {
            // Task was rescheduled
        } else {
            UIConstants.showSnackBar(message: error.localizedDescription)
        }
    }

    public static func openUrl(_ string: String, from viewController: UIViewController) {
        if let url = URL(string: string) {
            openUrl(url, from: viewController)
        }
    }

    public static func openUrl(_ url: URL, from viewController: UIViewController) {
        #if ISEXTENSION
        viewController.extensionContext?.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    public static func presentLinkPreviewForFile(
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
        metadata.title = file.isDropbox ? KDriveResourcesStrings.Localizable.buttonShareDropboxLink : KDriveResourcesStrings
            .Localizable.buttonSharePublicLink
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
