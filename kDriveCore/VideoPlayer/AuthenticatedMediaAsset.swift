/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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

import Alamofire
import AVFoundation
import Foundation
import OSLog

final class AuthenticatedMediaAsset: AVURLAsset, @unchecked Sendable {
    private let resourceLoaderDelegate: AuthenticatedMediaResourceLoader

    init?(url: URL, apiFetcher: DriveApiFetcher) {
        guard let wrappedURL = AuthenticatedMediaResourceLoader.wrap(url) else {
            Logger.general.error("Authenticated media asset rejected an invalid source URL")
            return nil
        }

        Logger.general.debug("Creating authenticated media asset for host \(url.host ?? "unknown", privacy: .public)")

        let resourceLoaderDelegate = AuthenticatedMediaResourceLoader(sourceURL: url, apiFetcher: apiFetcher)
        self.resourceLoaderDelegate = resourceLoaderDelegate

        super.init(url: wrappedURL, options: nil)
        resourceLoader.setDelegate(resourceLoaderDelegate, queue: resourceLoaderDelegate.queue)
    }
}

final class AuthenticatedMediaResourceLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    enum ResourceLoaderError: Error {
        case invalidResponse
        case unexpectedSource
    }

    fileprivate let queue = DispatchQueue(label: "com.infomaniak.kdrive.authenticated-media-loader")

    private static let customScheme = "kdrive-authenticated-media"
    private static let allowedHostSuffix = ".download.kdrive.infomaniakusercontent.com"
    private static let redirectStatusCodes = [301, 302, 303, 307, 308]

    private let sourceURL: URL
    private let apiFetcher: DriveApiFetcher
    private var requests = [ObjectIdentifier: DataRequest]()

    init(sourceURL: URL, apiFetcher: DriveApiFetcher) {
        self.sourceURL = sourceURL
        self.apiFetcher = apiFetcher
    }

    /// Only the URL this loader was created for may receive authenticated requests.
    /// Any other URL, such as one referenced by a playlist, is rejected.
    static func isSameResource(_ url: URL, as expectedURL: URL) -> Bool {
        guard let lhs = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rhs = URLComponents(url: expectedURL, resolvingAgainstBaseURL: false) else {
            return false
        }

        return lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && lhs.port == rhs.port
            && lhs.percentEncodedPath == rhs.percentEncodedPath
            && lhs.percentEncodedQuery == rhs.percentEncodedQuery
    }

    static func wrap(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https" else {
            return nil
        }

        components.scheme = customScheme
        return components.url
    }

    static func unwrap(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == customScheme else {
            return nil
        }

        components.scheme = "https"
        return components.url
    }

    static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased() else {
            return false
        }

        return host.hasSuffix(allowedHostSuffix)
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let wrappedURL = loadingRequest.request.url,
              let sourceURL = Self.unwrap(wrappedURL) else {
            Logger.general.error("Authenticated media resource loader rejected an invalid loading request")
            return false
        }

        guard Self.isSameResource(sourceURL, as: self.sourceURL) else {
            Logger.general.error("Authenticated media resource loader rejected an unexpected source URL")
            loadingRequest.finishLoading(with: ResourceLoaderError.unexpectedSource)
            return false
        }

        Logger.general.debug(
            "Authenticated media resource loader requesting host \(sourceURL.host ?? "unknown", privacy: .public)"
        )

        var request = loadingRequest.request
        request.url = sourceURL
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        let requestIdentifier = ObjectIdentifier(loadingRequest)
        let dataRequest = apiFetcher.authenticatedSession
            .request(request)
            .redirect(using: Redirector.doNotFollow)
            .response(queue: queue) { [weak self] response in
                guard let self else { return }
                requests.removeValue(forKey: requestIdentifier)

                guard !loadingRequest.isCancelled else {
                    Logger.general.debug("Authenticated media resource loading request was cancelled")
                    return
                }

                guard response.error == nil,
                      let httpResponse = response.response,
                      Self.redirectStatusCodes.contains(httpResponse.statusCode),
                      let location = httpResponse.value(forHTTPHeaderField: "Location"),
                      let redirectURL = URL(string: location, relativeTo: sourceURL)?.absoluteURL,
                      Self.isAllowed(redirectURL) else {
                    Logger.general.error(
                        "Authenticated media resource loader rejected redirect with HTTP status \(response.response?.statusCode ?? 0)"
                    )
                    loadingRequest.finishLoading(with: ResourceLoaderError.invalidResponse)
                    return
                }

                Logger.general.debug(
                    "Authenticated media resource loader accepted redirect to host \(redirectURL.host ?? "unknown", privacy: .public)"
                )

                var redirectRequest = loadingRequest.request
                redirectRequest.url = redirectURL
                redirectRequest.setValue(nil, forHTTPHeaderField: "Authorization")
                loadingRequest.response = httpResponse
                loadingRequest.redirect = redirectRequest
                loadingRequest.finishLoading()
                Logger.general.debug("Authenticated media resource loader completed redirect")
            }

        requests[requestIdentifier] = dataRequest
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        Logger.general.debug("Cancelling authenticated media resource loading request")
        requests.removeValue(forKey: ObjectIdentifier(loadingRequest))?.cancel()
    }
}
