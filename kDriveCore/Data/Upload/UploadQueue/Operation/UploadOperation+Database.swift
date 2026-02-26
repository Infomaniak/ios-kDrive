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
import RealmSwift

// periphery:ignore
extension UploadOperation {
    /// The standard way to interact with a UploadFile within an UploadOperation
    ///
    /// Lock access to file if upload operation `isFinished`, by throwing a `ErrorDomain.operationFinished`
    ///
    ///  This method can be called within an existing transaction, as database commits are performed with a `safeWrite`
    /// - Parameters:
    ///   - function: The name of the function performing the transaction
    ///   - task: A closure to mutate the current `UploadFile`
    func transactionWithFile(function: StaticString = #function, _ task: @escaping (_ file: UploadFile) throws -> Void) throws {
        // A cancelled operation can access database for cleanup, _not_ a finished one.
        guard !isFinished else {
            throw ErrorDomain.operationFinished
        }

        try uploadsDatabase.writeTransaction { writableRealm in
            guard let file = writableRealm.object(ofType: UploadFile.self, forPrimaryKey: self.uploadFileId) else {
                throw ErrorDomain.databaseUploadFileNotFound
            }

            try task(file)

            writableRealm.add(file, update: .modified)
        }
    }

    /// The standard way to interact with a `UploadingChunkTask` within an UploadOperation
    ///
    /// Lock access to UploadingChunkTask if upload operation `isFinished`, by throwing a `ErrorDomain.operationFinished`
    /// - Parameters:
    ///   - taskIdentifier: The task identifier used to upload a chunk
    ///   - matched: A closure to mutate the current `UploadingChunkTask`
    ///   - notFound: A closure called when the chunk was not found
    func transactionWithChunk(taskIdentifier: String,
                              matched: @escaping (_ chunkTask: inout UploadingChunkTask) throws -> Void,
                              notFound: @escaping () throws -> Void) throws {
        try transactionWithFile { file in
            // update current UploadFile with chunk
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            // Match chunk task with Session identifier
            let taskIdentifierPredicate = NSPredicate(format: "taskIdentifier = %@", taskIdentifier)

            // Silence warning as I'm using a Realm request.
            // swiftlint:disable:next first_where
            guard var chunkTask = uploadingSessionTask.chunkTasks.filter(taskIdentifierPredicate).first else {
                try notFound()
                return
            }

            try matched(&chunkTask)
        }
    }

    /// The standard way to interact with a `UploadingChunkTask` within an UploadOperation
    ///
    /// Lock access to UploadingChunkTask if upload operation `isFinished`, by throwing a `ErrorDomain.operationFinished`
    /// - Parameters:
    ///   - number: The uniq ID of a UploadingChunkTask
    ///   - matched: A closure to mutate the current `UploadingChunkTask`
    ///   - notFound: A closure called when the chunk was not found
    func transactionWithChunk(number chunkNumber: Int64,
                              matched: @escaping (_ chunkTask: inout UploadingChunkTask) throws -> Void,
                              notFound: @escaping () throws -> Void) throws {
        try transactionWithFile { file in
            // update current UploadFile with chunk
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            // Match chunk task with chunk number (id)
            let chunkNumberPredicate = NSPredicate(format: "chunkNumber = %lld", chunkNumber)

            // Silence warning as I'm using a Realm request.
            // swiftlint:disable:next first_where
            guard var chunkTask = uploadingSessionTask.chunkTasks.filter(chunkNumberPredicate).first else {
                try notFound()
                return
            }

            try matched(&chunkTask)
        }
    }

    /// Provides a read only and detached  `UploadFile`, regardless of the state of the operation.
    ///
    /// Throws if any DB access issues
    /// Does not check upload.finished state of the upload operation
    func readOnlyFile() throws -> UploadFile {
        guard let file = uploadsDatabase.fetchObject(ofType: UploadFile.self, forPrimaryKey: uploadFileId) else {
            throw ErrorDomain.databaseUploadFileNotFound
        }

        return file.detached()
    }

    /// Delete the UploadFile entity from database from forPrimaryKey of the current UploadOperation
    func deleteUploadFile() async throws {
        try uploadsDatabase.writeTransaction { writableRealm in
            guard let uploadFile = writableRealm.object(ofType: UploadFile.self, forPrimaryKey: self.uploadFileId) else {
                return
            }

            writableRealm.delete(uploadFile)
        }
    }
}
