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

@testable import InfomaniakDI
@testable import kDrive
@testable import kDriveCore
import XCTest

final class MckNavigationManageable_navigate: NavigationManageable {
    func showStore(from viewController: UIViewController, driveFileManager: DriveFileManager) {
        XCTFail("unexpected call to \(#function)")
    }

    func showSaveFileVC(from viewController: UIViewController, driveFileManager: DriveFileManager, file: ImportedFile) {
        XCTFail("unexpected call to \(#function)")
    }

    var navigateToCount = 0
    var navigateToRoute: NavigationRoutes?
    func navigate(to route: NavigationRoutes) {
        navigateToCount += 1
        navigateToRoute = route
    }
}

final class UTNavigationManager: XCTestCase {
    override func setUp() {
        SimpleResolver.sharedResolver.removeAll()
        super.setUp()
    }

    // MARK: - Upload observation

    func testDeeplinkFileSharing() {
        // GIVEN
        let mckNavigation = MckNavigationManageable_navigate()
        let navigationManagerFactory = Factory(type: NavigationManageable.self) { _, _ in
            return mckNavigation
        }
        SimpleResolver.sharedResolver.store(factory: navigationManagerFactory)
        let expectedFile = ImportedFile(name: "name", path: URL(string: "http://infoamaniak.com")!, uti: .aiff)
        let expectedRoute = NavigationRoutes.saveFile(file: expectedFile)

        // WHEN
        @InjectService var navigationManager: NavigationManageable
        navigationManager.navigate(to: expectedRoute)

        // THEN
        XCTAssertEqual(mckNavigation.navigateToCount, 1, "navigate method should be called once")
        guard let fetchedRoute = mckNavigation.navigateToRoute else {
            XCTFail("Expecting a valid route")
            return
        }
        XCTAssertEqual(fetchedRoute, expectedRoute, "should be the same route")
    }

    func testDeeplinkStore() {
        // GIVEN
        let mckNavigation = MckNavigationManageable_navigate()
        let navigationManagerFactory = Factory(type: NavigationManageable.self) { _, _ in
            return mckNavigation
        }
        SimpleResolver.sharedResolver.store(factory: navigationManagerFactory)
        let expectedRoute = NavigationRoutes.store(driveId: 123, userId: 456)

        // WHEN
        @InjectService var navigationManager: NavigationManageable
        navigationManager.navigate(to: expectedRoute)

        // THEN
        XCTAssertEqual(mckNavigation.navigateToCount, 1, "navigate method should be called once")
        guard let fetchedRoute = mckNavigation.navigateToRoute else {
            XCTFail("Expecting a valid route")
            return
        }
        XCTAssertEqual(fetchedRoute, expectedRoute, "should be the same route")
    }
}

/// Sanity checks on NavigationRoutes equality, as other tests rely on it
final class UTNavigationRoutes: XCTestCase {
    override func setUp() {
        SimpleResolver.sharedResolver.removeAll()
        super.setUp()
    }

    // MARK: File

    func testRouteEqual_File() {
        // GIVEN
        let expectedFile = ImportedFile(name: "name", path: URL(string: "http://infoamaniak.com")!, uti: .aiff)
        let routeA = NavigationRoutes.saveFile(file: expectedFile)
        let routeB = NavigationRoutes.saveFile(file: expectedFile)

        // THEN
        XCTAssertEqual(routeA, routeB)
    }

    func testRouteNotEqualUTI_File() {
        // GIVEN
        let fileA = ImportedFile(name: "name", path: URL(string: "http://infoamaniak.com")!, uti: .aiff)
        let fileB = ImportedFile(name: "name", path: URL(string: "http://infoamaniak.com")!, uti: .jpeg)
        let routeA = NavigationRoutes.saveFile(file: fileA)
        let routeB = NavigationRoutes.saveFile(file: fileB)

        // THEN
        XCTAssertNotEqual(routeA, routeB)
    }

    func testRouteNotEqualURL_File() {
        // GIVEN
        let fileA = ImportedFile(name: "name", path: URL(string: "http://infoamaniak.com")!, uti: .jpeg)
        let fileB = ImportedFile(name: "name", path: URL(string: "http://infoamaniak.ch")!, uti: .jpeg)
        let routeA = NavigationRoutes.saveFile(file: fileA)
        let routeB = NavigationRoutes.saveFile(file: fileB)

        // THEN
        XCTAssertNotEqual(routeA, routeB)
    }

    func testRouteNotEqualName_File() {
        // GIVEN
        let fileA = ImportedFile(name: "name", path: URL(string: "http://infoamaniak.com")!, uti: .jpeg)
        let fileB = ImportedFile(name: "another", path: URL(string: "http://infoamaniak.com")!, uti: .jpeg)
        let routeA = NavigationRoutes.saveFile(file: fileA)
        let routeB = NavigationRoutes.saveFile(file: fileB)

        // THEN
        XCTAssertNotEqual(routeA, routeB)
    }

    // MARK: Store

    func testRouteEqual_Store() {
        // GIVEN
        let routeA = NavigationRoutes.store(driveId: 123, userId: 456)
        let routeB = NavigationRoutes.store(driveId: 123, userId: 456)

        // THEN
        XCTAssertEqual(routeA, routeB)
    }

    func testRouteNotEqual_Store() {
        // GIVEN
        let routeA = NavigationRoutes.store(driveId: 456, userId: 123)
        let routeB = NavigationRoutes.store(driveId: 123, userId: 456)

        // THEN
        XCTAssertNotEqual(routeA, routeB)
    }
}
