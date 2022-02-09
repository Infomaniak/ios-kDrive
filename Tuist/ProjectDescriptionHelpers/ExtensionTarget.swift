//
//  ExtensionTarget.swift
//  Config
//
//  Created by Philippe Weidmann on 09.02.22.
//

import ProjectDescription

public extension Target {
    static func extensionTarget(name: String, bundleId: String, entitlements: Path, additionalResources: [ResourceFileElement] = [], settings: Settings) -> Target {
        var resources: [ResourceFileElement] = [
            "\(name)/**/*.storyboard",
            "kDrive/UI/Controller/Files/**/*.storyboard",
            "kDrive/UI/Controller/Floating Panel Information/*.storyboard",
            "kDrive/UI/Controller/NewFolder/*.storyboard",
            "kDrive/UI/View/EmptyTableView/**/*.xib",
            "kDrive/UI/View/Header view/**/*.xib",
            "kDrive/UI/View/Generic/**/*.xib",
            "kDrive/UI/View/Files/FileCollectionViewCell.xib",
            "kDrive/UI/View/Files/FileGridCollectionViewCell.xib",
            "kDrive/UI/View/Files/Categories/**/*.xib",
            "kDrive/UI/View/Files/FileDetail/ShareLink/*.xib",
            "kDrive/UI/View/Files/SaveFile/*.xib",
            "kDrive/UI/View/Files/Search/*.xib",
            "kDrive/UI/View/Files/Upload/*.xib",
            "kDrive/UI/View/Files/FloatingPanel/FloatingPanelSortOptionTableViewCell.xib",
            "kDrive/UI/View/Files/FloatingPanel/FloatingPanelQuickActionCollectionViewCell.xib",
            "kDrive/UI/View/Files/FloatingPanel/FloatingPanelTableViewCell.xib",
            "kDrive/UI/View/Footer view/*.xib",
            "kDrive/UI/View/Menu/MenuTableViewCell.xib",
            "kDrive/UI/View/Menu/SwitchUser/*.xib",
            "kDrive/UI/View/NewFolder/*.xib",
            "kDrive/**/*.xcassets",
            "kDrive/**/Localizable.strings",
            "kDrive/**/*.stringsdict",
            "kDrive/**/*.json"
        ]
        resources.append(contentsOf: additionalResources)

        return Target(name: name,
                      platform: .iOS,
                      product: .appExtension,
                      bundleId: bundleId,
                      deploymentTarget: Constants.deploymentTarget,
                      infoPlist: .file(path: "\(name)/Info.plist"),
                      sources: [
                          "\(name)/**",
                          "kDrive/UI/Controller/FloatingPanelSelectOptionViewController.swift",
                          "kDrive/UI/Controller/Create File/FloatingPanelUtils.swift",
                          "kDrive/UI/Controller/Files/Categories/**",
                          "kDrive/UI/Controller/Files/Rights and Share/**",
                          "kDrive/UI/Controller/Files/Save File/**",
                          "kDrive/UI/Controller/Files/Search/**",
                          "kDrive/UI/Controller/Files/MultipleSelectionViewController.swift",
                          "kDrive/UI/Controller/Files/FileListViewController.swift",
                          "kDrive/UI/Controller/Files/FloatingPanelSortOptionTableViewController.swift",
                          "kDrive/UI/Controller/Floating Panel Information/**",
                          "kDrive/UI/Controller/NewFolder/**",
                          "kDrive/UI/Controller/Storyboard.swift",
                          "kDrive/UI/View/EmptyTableView/**",
                          "kDrive/UI/View/Header view/**",
                          "kDrive/UI/View/Generic/**",
                          "kDrive/UI/View/Files/Categories/**",
                          "kDrive/UI/View/Files/FileDetail/ShareLink/**",
                          "kDrive/UI/View/Files/SaveFile/**",
                          "kDrive/UI/View/Files/Search/**",
                          "kDrive/UI/View/Files/Upload/**",
                          "kDrive/UI/View/Files/FileCollectionViewCell.swift",
                          "kDrive/UI/View/Files/FileGridCollectionViewCell.swift",
                          "kDrive/UI/View/Files/SwipableCell.swift",
                          "kDrive/UI/View/Files/SwipableCollectionView.swift",
                          "kDrive/UI/View/Files/FloatingPanel/FloatingPanelSortOptionTableViewCell.swift",
                          "kDrive/UI/View/Files/FloatingPanel/FloatingPanelQuickActionCollectionViewCell.swift",
                          "kDrive/UI/View/Files/FloatingPanel/FloatingPanelTableViewCell.swift",
                          "kDrive/UI/View/Footer view/**",
                          "kDrive/UI/View/Menu/SwitchUser/**",
                          "kDrive/UI/View/Menu/MenuTableViewCell.swift",
                          "kDrive/UI/View/NewFolder/**",
                          "kDrive/Utils/**"
                      ],
                      resources: ResourceFileElements(resources: resources),
                      entitlements: entitlements,
                      scripts: [Constants.swiftlintScript],
                      dependencies: [
                          .target(name: "kDriveCore"),
                          .package(product: "FloatingPanel"),
                          .package(product: "Lottie"),
                          .package(product: "DropDown"),
                          .package(product: "HorizonCalendar")
                      ],
                      settings: settings)
    }

}
