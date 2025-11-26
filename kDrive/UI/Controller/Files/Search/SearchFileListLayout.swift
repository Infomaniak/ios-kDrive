/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import kDriveCore
import kDriveResources
import UIKit

struct SearchFileListLayout: FileListLayout {
    func createLayoutFor(viewModel: FileListViewModel) -> UICollectionViewLayout {
        guard let searchViewModel = viewModel as? SearchFilesViewModel else {
            return DefaultFileListLayout().createLayoutFor(viewModel: viewModel)
        }

        if searchViewModel.isDisplayingSearchResults {
            return createRecentSearchesLayoutFor(viewModel: viewModel)
        } else {
            return DefaultFileListLayout().createLayoutFor(viewModel: viewModel)
        }
    }

    private func createRecentSearchesLayoutFor(viewModel: FileListViewModel) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, layoutEnvironment in
            DefaultFileListLayout().createListLayout(environment: layoutEnvironment, viewModel: viewModel)
        }

        return layout
    }
}
