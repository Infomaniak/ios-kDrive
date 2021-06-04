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

import Foundation
import MobileCoreServices

public struct UTI: RawRepresentable {

    public var rawValue: CFString

    public var identifier: String {
        return rawValue as String
    }

    public var preferredFilenameExtension: String? {
        return UTTypeCopyPreferredTagWithClass(rawValue, kUTTagClassFilenameExtension)?.takeRetainedValue() as String?
    }

    public var preferredMIMEType: String? {
        return UTTypeCopyPreferredTagWithClass(rawValue, kUTTagClassMIMEType)?.takeRetainedValue() as String?
    }

    public var localizedDescription: String? {
        return UTTypeCopyDescription(rawValue)?.takeRetainedValue() as String?
    }

    public var isDynamic: Bool {
        return UTTypeIsDynamic(rawValue)
    }

    public var isDeclared: Bool {
        return UTTypeIsDeclared(rawValue)
    }

    public init?(_ identifier: String) {
        let allUTIs: [UTI] = [.item, .content, .compositeContent, .diskImage, .data, .directory, .resolvable, .symbolicLink, .executable, .mountPoint, .aliasFile, .urlBookmarkData, .url, .fileURL, .text, .plainText, .utf8PlainText, .utf16ExternalPlainText, .utf16PlainText, .delimitedText, .commaSeparatedText, .tabSeparatedText, .utf8TabSeparatedText, .rtf, .html, .xml, .sourceCode, .assemblyLanguageSource, .cSource, .objectiveCSource, .swiftSource, .cPlusPlusSource, .objectiveCPlusPlusSource, .cHeader, .cPlusPlusHeader, .script, .appleScript, .osaScript, .osaScriptBundle, .javaScript, .shellScript, .perlScript, .pythonScript, .rubyScript, .phpScript, .json, .propertyList, .xmlPropertyList, .binaryPropertyList, .pdf, .rtfd, .flatRTFD, .webArchive, .image, .jpeg, .tiff, .gif, .png, .icns, .bmp, .ico, .rawImage, .svg, .livePhoto, .heic, .threeDContent, .audiovisualContent, .movie, .video, .audio, .quickTimeMovie, .mpeg, .mpeg2Video, .mpeg2TransportStream, .mp3, .mpeg4Movie, .mpeg4Audio, .appleProtectedMPEG4Audio, .appleProtectedMPEG4Video, .avi, .aiff, .wav, .midi, .playlist, .m3uPlaylist, .folder, .volume, .package, .bundle, .pluginBundle, .spotlightImporter, .quickLookGenerator, .xpcService, .framework, .application, .applicationBundle, .unixExecutable, .exe, .systemPreferencesPane, .archive, .gzip, .bz2, .zip, .spreadsheet, .presentation, .database, .message, .contact, .vCard, .toDoItem, .calendarEvent, .emailMessage, .internetLocation, .font, .bookmark, .pkcs12, .x509Certificate, .epub, .log]
        guard let rawValue = allUTIs.first(where: { $0.identifier == identifier })?.rawValue else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init?(filenameExtension: String, conformingTo supertype: UTI = .data) {
        guard let rawValue = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, filenameExtension as CFString, supertype.identifier as CFString)?.takeRetainedValue() else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init?(mimeType: String, conformingTo supertype: UTI = .data) {
        guard let rawValue = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, supertype.identifier as CFString)?.takeRetainedValue() else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(rawValue: CFString) {
        self.rawValue = rawValue
    }

    public func conforms(to type: UTI) -> Bool {
        return UTTypeConformsTo(rawValue, type.rawValue)
    }

    public static let item = UTI(rawValue: kUTTypeItem)

    public static let content = UTI(rawValue: kUTTypeContent)

    public static let compositeContent = UTI(rawValue: kUTTypeCompositeContent)

    public static let diskImage = UTI(rawValue: kUTTypeDiskImage)

    public static let data = UTI(rawValue: kUTTypeData)

    public static let directory = UTI(rawValue: kUTTypeDirectory)

    public static let resolvable = UTI(rawValue: kUTTypeResolvable)

    public static let symbolicLink = UTI(rawValue: kUTTypeSymLink)

    public static let executable = UTI(rawValue: kUTTypeExecutable)

    public static let mountPoint = UTI(rawValue: kUTTypeMountPoint)

    public static let aliasFile = UTI(rawValue: kUTTypeAliasFile)

    public static let urlBookmarkData = UTI(rawValue: kUTTypeURLBookmarkData)

    public static let url = UTI(rawValue: kUTTypeURL)

    public static let fileURL = UTI(rawValue: kUTTypeFileURL)

    public static let text = UTI(rawValue: kUTTypeText)

    public static let plainText = UTI(rawValue: kUTTypePlainText)

    public static let utf8PlainText = UTI(rawValue: kUTTypeUTF8PlainText)

    public static let utf16ExternalPlainText = UTI(rawValue: kUTTypeUTF16ExternalPlainText)

    public static let utf16PlainText = UTI(rawValue: kUTTypeUTF16PlainText)

    public static let delimitedText = UTI(rawValue: kUTTypeDelimitedText)

    public static let commaSeparatedText = UTI(rawValue: kUTTypeCommaSeparatedText)

    public static let tabSeparatedText = UTI(rawValue: kUTTypeTabSeparatedText)

    public static let utf8TabSeparatedText = UTI(rawValue: kUTTypeUTF8TabSeparatedText)

    public static let rtf = UTI(rawValue: kUTTypeRTF)

    public static let html = UTI(rawValue: kUTTypeHTML)

    public static let xml = UTI(rawValue: kUTTypeXML)

    public static let sourceCode = UTI(rawValue: kUTTypeSourceCode)

    public static let assemblyLanguageSource = UTI(rawValue: kUTTypeAssemblyLanguageSource)

    public static let cSource = UTI(rawValue: kUTTypeCSource)

    public static let objectiveCSource = UTI(rawValue: kUTTypeObjectiveCSource)

    public static let swiftSource = UTI(rawValue: kUTTypeSwiftSource)

    public static let cPlusPlusSource = UTI(rawValue: kUTTypeCPlusPlusSource)

    public static let objectiveCPlusPlusSource = UTI(rawValue: kUTTypeObjectiveCPlusPlusSource)

    public static let cHeader = UTI(rawValue: kUTTypeCHeader)

    public static let cPlusPlusHeader = UTI(rawValue: kUTTypeCPlusPlusHeader)

    public static let script = UTI(rawValue: kUTTypeScript)

    public static let appleScript = UTI(rawValue: kUTTypeAppleScript)

    public static let osaScript = UTI(rawValue: kUTTypeOSAScript)

    public static let osaScriptBundle = UTI(rawValue: kUTTypeOSAScriptBundle)

    public static let javaScript = UTI(rawValue: kUTTypeJavaScript)

    public static let shellScript = UTI(rawValue: kUTTypeShellScript)

    public static let perlScript = UTI(rawValue: kUTTypePerlScript)

    public static let pythonScript = UTI(rawValue: kUTTypePythonScript)

    public static let rubyScript = UTI(rawValue: kUTTypeRubyScript)

    public static let phpScript = UTI(rawValue: kUTTypePHPScript)

    public static let json = UTI(rawValue: kUTTypeJSON)

    public static let propertyList = UTI(rawValue: kUTTypePropertyList)

    public static let xmlPropertyList = UTI(rawValue: kUTTypeXMLPropertyList)

    public static let binaryPropertyList = UTI(rawValue: kUTTypeBinaryPropertyList)

    public static let pdf = UTI(rawValue: kUTTypePDF)

    public static let rtfd = UTI(rawValue: kUTTypeRTFD)

    public static let flatRTFD = UTI(rawValue: kUTTypeFlatRTFD)

    public static let webArchive = UTI(rawValue: kUTTypeWebArchive)

    public static let image = UTI(rawValue: kUTTypeImage)

    public static let jpeg = UTI(rawValue: kUTTypeJPEG)

    public static let tiff = UTI(rawValue: kUTTypeTIFF)

    public static let gif = UTI(rawValue: kUTTypeGIF)

    public static let png = UTI(rawValue: kUTTypePNG)

    public static let icns = UTI(rawValue: kUTTypeAppleICNS)

    public static let bmp = UTI(rawValue: kUTTypeBMP)

    public static let ico = UTI(rawValue: kUTTypeICO)

    public static let rawImage = UTI(rawValue: kUTTypeRawImage)

    public static let svg = UTI(rawValue: kUTTypeScalableVectorGraphics)

    public static let livePhoto = UTI(rawValue: kUTTypeLivePhoto)

    public static let heic = UTI(rawValue: "public.heic" as CFString)

    public static let threeDContent = UTI(rawValue: kUTType3DContent)

    public static let audiovisualContent = UTI(rawValue: kUTTypeAudiovisualContent)

    public static let movie = UTI(rawValue: kUTTypeMovie)

    public static let video = UTI(rawValue: kUTTypeVideo)

    public static let audio = UTI(rawValue: kUTTypeAudio)

    public static let quickTimeMovie = UTI(rawValue: kUTTypeQuickTimeMovie)

    public static let mpeg = UTI(rawValue: kUTTypeMPEG)

    public static let mpeg2Video = UTI(rawValue: kUTTypeMPEG2Video)

    public static let mpeg2TransportStream = UTI(rawValue: kUTTypeMPEG2TransportStream)

    public static let mp3 = UTI(rawValue: kUTTypeMP3)

    public static let mpeg4Movie = UTI(rawValue: kUTTypeMPEG4)

    public static let mpeg4Audio = UTI(rawValue: kUTTypeMPEG4Audio)

    public static let appleProtectedMPEG4Audio = UTI(rawValue: kUTTypeAppleProtectedMPEG4Audio)

    public static let appleProtectedMPEG4Video = UTI(rawValue: kUTTypeAppleProtectedMPEG4Video)

    public static let avi = UTI(rawValue: kUTTypeAVIMovie)

    public static let aiff = UTI(rawValue: kUTTypeAudioInterchangeFileFormat)

    public static let wav = UTI(rawValue: kUTTypeWaveformAudio)

    public static let midi = UTI(rawValue: kUTTypeMIDIAudio)

    public static let playlist = UTI(rawValue: kUTTypePlaylist)

    public static let m3uPlaylist = UTI(rawValue: kUTTypeM3UPlaylist)

    public static let folder = UTI(rawValue: kUTTypeFolder)

    public static let volume = UTI(rawValue: kUTTypeVolume)

    public static let package = UTI(rawValue: kUTTypePackage)

    public static let bundle = UTI(rawValue: kUTTypeBundle)

    public static let pluginBundle = UTI(rawValue: kUTTypePluginBundle)

    public static let spotlightImporter = UTI(rawValue: kUTTypeSpotlightImporter)

    public static let quickLookGenerator = UTI(rawValue: kUTTypeQuickLookGenerator)

    public static let xpcService = UTI(rawValue: kUTTypeXPCService)

    public static let framework = UTI(rawValue: kUTTypeFramework)

    public static let application = UTI(rawValue: kUTTypeApplication)

    public static let applicationBundle = UTI(rawValue: kUTTypeApplicationBundle)

    public static let unixExecutable = UTI(rawValue: kUTTypeUnixExecutable)

    public static let exe = UTI(rawValue: kUTTypeWindowsExecutable)

    public static let systemPreferencesPane = UTI(rawValue: kUTTypeSystemPreferencesPane)

    public static let archive = UTI(rawValue: kUTTypeArchive)

    public static let gzip = UTI(rawValue: kUTTypeGNUZipArchive)

    public static let bz2 = UTI(rawValue: kUTTypeBzip2Archive)

    public static let zip = UTI(rawValue: kUTTypeZipArchive)

    public static let spreadsheet = UTI(rawValue: kUTTypeSpreadsheet)

    public static let presentation = UTI(rawValue: kUTTypePresentation)

    public static let database = UTI(rawValue: kUTTypeDatabase)

    public static let message = UTI(rawValue: kUTTypeMessage)

    public static let contact = UTI(rawValue: kUTTypeContact)

    public static let vCard = UTI(rawValue: kUTTypeVCard)

    public static let toDoItem = UTI(rawValue: kUTTypeToDoItem)

    public static let calendarEvent = UTI(rawValue: kUTTypeCalendarEvent)

    public static let emailMessage = UTI(rawValue: kUTTypeEmailMessage)

    public static let internetLocation = UTI(rawValue: kUTTypeInternetLocation)

    public static let font = UTI(rawValue: kUTTypeFont)

    public static let bookmark = UTI(rawValue: kUTTypeBookmark)

    public static let pkcs12 = UTI(rawValue: kUTTypePKCS12)

    public static let x509Certificate = UTI(rawValue: kUTTypeX509Certificate)

    public static let epub = UTI(rawValue: kUTTypeElectronicPublication)

    public static let log = UTI(rawValue: kUTTypeLog)

}

extension UTI: Equatable, Hashable {

    public static func == (lhs: UTI, rhs: UTI) -> Bool {
        return UTTypeEqual(lhs.rawValue, rhs.rawValue)
    }

}

extension UTI: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        return localizedDescription ?? identifier
    }

    public var debugDescription: String {
        return identifier
    }

}
