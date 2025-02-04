// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescription
import ProjectDescriptionHelpers

let packageSettings = PackageSettings(
    productTypes: [
        "RealmSwift": .staticLibrary,
        "Realm": .staticLibrary
    ]
)

#endif

let package = Package(
    name: "Dependencies",
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.2.2")),
        .package(url: "https://github.com/Infomaniak/ios-core", .upToNextMajor(from: "13.0.0")),
        .package(url: "https://github.com/Infomaniak/ios-core-ui", .upToNextMajor(from: "16.0.0")),
        .package(url: "https://github.com/Infomaniak/ios-login", .upToNextMajor(from: "7.2.0")),
        .package(url: "https://github.com/Infomaniak/ios-dependency-injection", .upToNextMajor(from: "2.0.2")),
        .package(url: "https://github.com/Infomaniak/swift-concurrency", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/Infomaniak/ios-version-checker", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/Infomaniak/LocalizeKit", .upToNextMajor(from: "1.0.2")),
        .package(url: "https://github.com/realm/realm-swift", .upToNextMajor(from: "10.52.0")),
        .package(url: "https://github.com/SCENEE/FloatingPanel", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/onevcat/Kingfisher", .upToNextMajor(from: "7.6.2")),
        .package(url: "https://github.com/flowbe/MaterialOutlinedTextField", .upToNextMajor(from: "0.1.0")),
        .package(url: "https://github.com/ProxymanApp/atlantis", .upToNextMajor(from: "1.3.0")),
        .package(url: "https://github.com/ra1028/DifferenceKit", .upToNextMajor(from: "1.3.0")),
        .package(url: "https://github.com/airbnb/lottie-ios", .upToNextMinor(from: "3.4.0")),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack", .upToNextMajor(from: "3.7.0")),
        .package(url: "https://github.com/Infomaniak/DropDown", branch: "master"),
        .package(url: "https://github.com/flowbe/SwiftRegex", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/getsentry/sentry-cocoa", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/Infomaniak/mqtt-nio", .upToNextMajor(from: "2.4.1")),
        .package(url: "https://github.com/airbnb/HorizonCalendar", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/Cocoanetics/Kvitto", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/raspu/Highlightr", .upToNextMajor(from: "2.1.0")),
        .package(url: "https://github.com/bmoliveira/MarkdownKit", .upToNextMajor(from: "1.7.0")),
        .package(url: "https://github.com/matomo-org/matomo-sdk-ios", .upToNextMajor(from: "7.5.1"))
    ]
)
