/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation
import InfomaniakCoreDB
@testable import InfomaniakDI
@testable import kDrive
@testable import kDriveCore
import RealmSwift
import Testing
import UIKit

extension ResolverTests {
    @Suite
    @MainActor
    struct UTSearchViewController {
        @Test func recentSearchesRenderBeforeViewDidLoadSetup() throws {
            let resolver = SimpleResolver.sharedResolver
            let savedFactories = resolver.factories
            let savedServices = resolver.store
            let defaults = UserDefaults.shared
            let recentSearchesKey = defaults.key(.recentSearches)
            let savedRecentSearches = defaults.object(forKey: recentSearchesKey)
            defer {
                defaults.set(savedRecentSearches, forKey: recentSearchesKey)
                resolver.removeAll()
                resolver.factories = savedFactories
                resolver.store = savedServices
            }

            resolver.removeAll()
            _ = TestTargetAssemblyHelper(configuration: .minimal)
            let configuration = Realm.Configuration(inMemoryIdentifier: UUID().uuidString)
            let realm = try Realm(configuration: configuration)
            let database = TransactionExecutor(realmAccessible: RealmAccessor(
                realmURL: nil, realmConfiguration: configuration, excludeFromBackup: false
            ))
            resolver.store(factory: Factory(type: Transactionable.self) { _, _ in database },
                           forCustomTypeIdentifier: kDriveDBID.driveInfo)

            let drive = Drive()
            drive.id = Int.random(in: 100_000 ... 999_999_999)
            drive.userId = drive.id
            let driveFileManager = DriveFileManager(drive: drive, apiFetcher: DriveApiFetcher())
            defer { _ = try? Realm.deleteFiles(for: driveFileManager.realmConfiguration) }
            defaults.recentSearches = ["Saved search"]

            let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager)
            let controller = EarlyLayoutSearchViewController(viewModel: viewModel, listLayout: SearchFileListLayout())
            let navigation = UINavigationController(rootViewController: controller)
            navigation.loadViewIfNeeded()
            controller.loadViewIfNeeded()

            let cell = try #require(controller.earlyCell)
            #expect(cell.recentSearchTitle.text == "Saved search")
            #expect(cell.contentInsetView != nil)
            #expect(cell.highlightedView != nil)
            #expect(controller.collectionView.numberOfItems(inSection: 0) == 1)
            withExtendedLifetime(realm) {}
        }
    }
}

@MainActor
private final class EarlyLayoutSearchViewController: SearchViewController {
    private(set) var earlyCell: RecentSearchCollectionViewCell?

    override func viewDidLoad() {
        // Reproduce a layout request before the base controller finishes its setup.
        collectionView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        earlyCell = collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? RecentSearchCollectionViewCell
        super.viewDidLoad()
    }
}
