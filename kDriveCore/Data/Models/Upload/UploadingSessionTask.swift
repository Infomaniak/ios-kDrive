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

import CryptoKit
import Foundation
import InfomaniakCore
import InfomaniakDI
import RealmSwift

/// Tracks the upload operation, given a session for a file
public final class UploadingSessionTask: EmbeddedObject {
    // MARK: - Persisted

    @Persisted public var uploadSession: UploadSession?
    @Persisted public var token: String
    @Persisted public var sessionExpiration: Date
    @Persisted public var chunkTasks: List<UploadingChunkTask>

    /// The source file path
    @Persisted public var filePath: String

    override public init() {
        // We have to keep it for Realm
    }

    public convenience init(uploadSession: UploadSession,
                            sessionExpiration: Date,
                            chunkTasks: List<UploadingChunkTask>,
                            filePath: String) {
        self.init()

        self.uploadSession = uploadSession
        self.sessionExpiration = sessionExpiration
        self.chunkTasks = chunkTasks
        self.filePath = filePath
    }

    // MARK: - Computed Properties

    public var isExpired: Bool {
        return Date() > sessionExpiration
    }
}
