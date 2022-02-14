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

import DifferenceKit
import Foundation
import kDriveCore
import RealmSwift

class PhotoListViewModel: ManagedFileListViewModel {
    private typealias Section = ArraySection<Group, File>

    private struct Group: Differentiable {
        let referenceDate: Date
        let dateComponents: DateComponents
        let sortMode: PhotoSortMode

        var differenceIdentifier: Date {
            return referenceDate
        }

        var formattedDate: String {
            return sortMode.dateFormatter.string(from: referenceDate)
        }

        init(referenceDate: Date, sortMode: PhotoSortMode) {
            self.referenceDate = referenceDate
            self.dateComponents = Calendar.current.dateComponents(sortMode.calendarComponents, from: referenceDate)
            self.sortMode = sortMode
        }

        func isContentEqual(to source: Group) -> Bool {
            return referenceDate == source.referenceDate && dateComponents == source.dateComponents && sortMode == source.sortMode
        }
    }

    private static let emptySections = [Section(model: Group(referenceDate: Date(), sortMode: .day), elements: [])]

    private var sections = emptySections
    private var shouldLoadMore = false

    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        super.init(configuration: Configuration(showUploadingFiles: false,
                                                emptyViewType: .noImages),
                   driveFileManager: driveFileManager,
                   currentDirectory: DriveFileManager.lastPicturesRootFile)
        self.files = AnyRealmCollection(driveFileManager.getRealm()
            .objects(File.self)
            .filter(NSPredicate(format: "rawConvertedType = %@", ConvertedType.image.rawValue))
            .sorted(by: [SortType.newer.value.sortDescriptor]))
    }

    override func getFile(at indexPath: IndexPath) -> File? {
        guard indexPath.section < sections.count else {
            return nil
        }
        let pictures = sections[indexPath.section].elements
        guard indexPath.row < pictures.count else {
            return nil
        }
        return pictures[indexPath.row]
    }
}
