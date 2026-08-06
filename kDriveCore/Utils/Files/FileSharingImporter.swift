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

import Darwin
import Foundation
import InfomaniakCore

protocol FileSharingImportable {
    func importFiles(from url: URL) async throws -> [ImportedFile]
}

enum FileSharingImportError: Error, Equatable {
    case invalidRoute
    case invalidQuery
    case tooManyFiles
    case invalidPath
    case duplicateFile
    case sourceOutsideHandoffRoot
    case invalidHandoffLayout
    case invalidFileName
    case unsupportedFile
    case fileTooLarge
    case aggregateSizeExceeded
    case insufficientSpace
    case unavailableStorage
    case stagingFailed
}

final class FileSharingImporter: FileSharingImportable {
    struct Limits {
        static let `default` = Limits(
            maximumFileCount: 100,
            maximumFileSize: Constants.rangeProviderConfig.fileMaxSizeClient - 1,
            maximumAggregateSize: Constants.rangeProviderConfig.fileMaxSizeClient - 1,
            freeSpaceReserve: 50 * 1024 * 1024
        )

        let maximumFileCount: Int
        let maximumFileSize: UInt64
        let maximumAggregateSize: UInt64
        let freeSpaceReserve: UInt64
    }

    private struct ValidatedFile {
        let source: OpenedFile
        let name: String
        let uti: UTI
        let fileExtension: String?
        let size: UInt64
    }

    private final class OpenedFile {
        let descriptor: Int32

        init(descriptor: Int32) {
            self.descriptor = descriptor
        }

        deinit {
            Darwin.close(descriptor)
        }
    }

    static let scheme = "kdrive-file-sharing"
    static let host = "file"

    private static let sharedAppGroup = "group.com.infomaniak"
    private static let handoffPathComponents = ["Library", "Caches", "file-sharing"]

    private let fileManager: FileManager
    private let sharedContainerURL: URL?
    private let stagingRootURL: URL
    private let limits: Limits
    private let makeIdentifier: () -> String
    private let availableCapacity: (URL) throws -> UInt64

    convenience init() {
        let fileManager = FileManager.default
        self.init(
            fileManager: fileManager,
            sharedContainerURL: fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.sharedAppGroup),
            stagingRootURL: DriveFileManager.constants.importDirectoryURL
        )
    }

    init(
        fileManager: FileManager,
        sharedContainerURL: URL?,
        stagingRootURL: URL,
        limits: Limits = .default,
        makeIdentifier: @escaping () -> String = { UUID().uuidString },
        availableCapacity: ((URL) throws -> UInt64)? = nil
    ) {
        self.fileManager = fileManager
        self.sharedContainerURL = sharedContainerURL
        self.stagingRootURL = stagingRootURL
        self.limits = limits
        self.makeIdentifier = makeIdentifier
        self.availableCapacity = availableCapacity ?? { url in
            let attributes = try fileManager.attributesOfFileSystem(forPath: url.path)
            guard let capacity = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value else {
                throw FileSharingImportError.unavailableStorage
            }
            return capacity
        }
    }

    func importFiles(from url: URL) async throws -> [ImportedFile] {
        return try await Task.detached(priority: .userInitiated) { [self] in
            let validatedFiles = try validate(url: url)
            try checkAvailableSpace(for: validatedFiles)
            return try stage(validatedFiles)
        }.value
    }

    private func validate(url: URL) throws -> [ValidatedFile] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == Self.scheme,
              components.host == Self.host,
              components.path.isEmpty,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil else {
            throw FileSharingImportError.invalidRoute
        }

        guard let queryItems = components.queryItems,
              !queryItems.isEmpty,
              queryItems.allSatisfy({ $0.name == "url" && !($0.value?.isEmpty ?? true) }) else {
            throw FileSharingImportError.invalidQuery
        }
        guard queryItems.count <= limits.maximumFileCount else {
            throw FileSharingImportError.tooManyFiles
        }
        guard let sharedContainerURL else {
            throw FileSharingImportError.unavailableStorage
        }

        let handoffRootURL = Self.handoffPathComponents.reduce(sharedContainerURL) { rootURL, component in
            rootURL.appendingPathComponent(component, isDirectory: true)
        }.standardizedFileURL
        let handoffRoot = try openDirectoryTree(
            rootURL: sharedContainerURL.standardizedFileURL,
            components: Self.handoffPathComponents
        )
        var canonicalPaths = Set<String>()
        var aggregateSize: UInt64 = 0

        return try queryItems.map { queryItem in
            guard let path = queryItem.value,
                  path.utf8.count < Int(PATH_MAX),
                  NSString(string: path).isAbsolutePath else {
                throw FileSharingImportError.invalidPath
            }

            let candidateURL = URL(fileURLWithPath: path).standardizedFileURL
            guard candidateURL.isContained(in: handoffRootURL) else {
                throw FileSharingImportError.sourceOutsideHandoffRoot
            }

            let relativeComponents = Array(candidateURL.pathComponents.dropFirst(handoffRootURL.pathComponents.count))
            guard relativeComponents.count == 2,
                  UUID(uuidString: relativeComponents[0]) != nil else {
                throw FileSharingImportError.invalidHandoffLayout
            }
            guard canonicalPaths.insert(candidateURL.path).inserted else {
                throw FileSharingImportError.duplicateFile
            }
            let safeName = relativeComponents[1]
            guard isValidFileName(safeName) else {
                throw FileSharingImportError.invalidFileName
            }

            let handoffDirectory = try openDirectory(at: handoffRoot.descriptor, component: relativeComponents[0])
            let source = try openFile(at: handoffDirectory.descriptor, component: safeName)
            var sourceInfo = stat()
            guard Darwin.fstat(source.descriptor, &sourceInfo) == 0,
                  sourceInfo.st_mode & S_IFMT == S_IFREG,
                  sourceInfo.st_nlink == 1,
                  sourceInfo.st_size >= 0 else {
                throw FileSharingImportError.unsupportedFile
            }
            let fileSize = UInt64(sourceInfo.st_size)
            guard fileSize <= limits.maximumFileSize else {
                throw FileSharingImportError.fileTooLarge
            }
            guard fileSize <= limits.maximumAggregateSize - aggregateSize else {
                throw FileSharingImportError.aggregateSizeExceeded
            }
            aggregateSize += fileSize

            let fileExtension = safeExtension(for: safeName)
            let uti = fileExtension.flatMap { UTI(filenameExtension: $0) } ?? .data
            return ValidatedFile(
                source: source,
                name: safeName,
                uti: uti,
                fileExtension: fileExtension,
                size: fileSize
            )
        }
    }

    private func checkAvailableSpace(for files: [ValidatedFile]) throws {
        let aggregateSize = files.reduce(UInt64(0)) { $0 + $1.size }
        guard aggregateSize <= UInt64.max - limits.freeSpaceReserve else {
            throw FileSharingImportError.aggregateSizeExceeded
        }

        let freeSize: UInt64
        do {
            freeSize = try availableCapacity(stagingRootURL)
        } catch {
            throw FileSharingImportError.unavailableStorage
        }
        guard freeSize >= aggregateSize + limits.freeSpaceReserve else {
            throw FileSharingImportError.insufficientSpace
        }
    }

    private func stage(_ files: [ValidatedFile]) throws -> [ImportedFile] {
        let stagingRoot: OpenedFile
        do {
            stagingRoot = try openDirectory(atPath: stagingRootURL.path)
        } catch {
            throw FileSharingImportError.unavailableStorage
        }

        var stagedNames = [String]()
        do {
            return try files.map { file in
                var destinationName = makeIdentifier()
                if let fileExtension = file.fileExtension {
                    destinationName += ".\(fileExtension)"
                }
                guard isValidFileName(destinationName) else {
                    throw FileSharingImportError.stagingFailed
                }

                let destination = try createFile(at: stagingRoot.descriptor, component: destinationName)
                stagedNames.append(destinationName)
                guard fcopyfile(file.source.descriptor, destination.descriptor, nil, copyfile_flags_t(COPYFILE_DATA)) == 0 else {
                    throw FileSharingImportError.stagingFailed
                }
                var sourceInfo = stat()
                guard Darwin.fstat(file.source.descriptor, &sourceInfo) == 0 else {
                    throw FileSharingImportError.stagingFailed
                }
                var timestamps = [sourceInfo.st_atimespec, sourceInfo.st_mtimespec]
                guard futimens(destination.descriptor, &timestamps) == 0 else {
                    throw FileSharingImportError.stagingFailed
                }

                var destinationInfo = stat()
                guard Darwin.fstat(destination.descriptor, &destinationInfo) == 0,
                      destinationInfo.st_mode & S_IFMT == S_IFREG,
                      destinationInfo.st_size >= 0,
                      UInt64(destinationInfo.st_size) == file.size else {
                    throw FileSharingImportError.stagingFailed
                }

                let destinationURL = stagingRootURL.appendingPathComponent(destinationName, isDirectory: false)
                return ImportedFile(name: file.name, path: destinationURL, uti: file.uti)
            }
        } catch {
            for name in stagedNames {
                name.withCString { unlinkat(stagingRoot.descriptor, $0, 0) }
            }
            throw FileSharingImportError.stagingFailed
        }
    }

    private func isValidFileName(_ fileName: String) -> Bool {
        let invalidCharacters = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\"))
        return !fileName.isEmpty
            && fileName != "."
            && fileName != ".."
            && fileName.utf8.count <= Int(NAME_MAX)
            && fileName.rangeOfCharacter(from: invalidCharacters) == nil
    }

    private func safeExtension(for fileName: String) -> String? {
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension
        guard !fileExtension.isEmpty,
              fileExtension.utf8.count <= 16,
              fileExtension.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else {
            return nil
        }
        return fileExtension
    }

    private func openDirectoryTree(rootURL: URL, components: [String]) throws -> OpenedFile {
        var directory = try openDirectory(atPath: rootURL.path)
        for component in components {
            directory = try openDirectory(at: directory.descriptor, component: component)
        }
        return directory
    }

    private func openDirectory(atPath path: String) throws -> OpenedFile {
        let descriptor = path.withCString { Darwin.open($0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC) }
        guard descriptor >= 0 else {
            throw FileSharingImportError.unavailableStorage
        }
        return OpenedFile(descriptor: descriptor)
    }

    private func openDirectory(at parentDescriptor: Int32, component: String) throws -> OpenedFile {
        let descriptor = component.withCString {
            openat(parentDescriptor, $0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard descriptor >= 0 else {
            throw FileSharingImportError.unsupportedFile
        }
        return OpenedFile(descriptor: descriptor)
    }

    private func openFile(at parentDescriptor: Int32, component: String) throws -> OpenedFile {
        let descriptor = component.withCString {
            openat(parentDescriptor, $0, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
        }
        guard descriptor >= 0 else {
            throw FileSharingImportError.unsupportedFile
        }
        return OpenedFile(descriptor: descriptor)
    }

    private func createFile(at parentDescriptor: Int32, component: String) throws -> OpenedFile {
        let descriptor = component.withCString {
            openat(parentDescriptor, $0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else {
            throw FileSharingImportError.stagingFailed
        }
        return OpenedFile(descriptor: descriptor)
    }
}

private extension URL {
    func isContained(in rootURL: URL) -> Bool {
        let rootComponents = rootURL.pathComponents
        let candidateComponents = pathComponents
        guard candidateComponents.count > rootComponents.count else {
            return false
        }
        return Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }
}
