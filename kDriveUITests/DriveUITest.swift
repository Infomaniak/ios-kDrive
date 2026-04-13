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

import kDriveCore
import kDriveResources
import XCTest

class AppUITest: XCTestCase {
    var app: XCUIApplication!
    let defaultTimeOut: TimeInterval = 30.0

    var tabBar: XCUIElementQuery {
        return app.tabBars
    }

    var navigationBars: XCUIElementQuery {
        return app.navigationBars
    }

    var tablesQuery: XCUIElementQuery {
        return app.tables
    }

    var collectionViewsQuery: XCUIElementQuery {
        return app.collectionViews
    }

    var buttons: XCUIElementQuery {
        return app.buttons
    }

    var currentName: String?

    static let defaultTimeout = 50.0

    func launchAppFromScratch(resetData: Bool = true) {
        if resetData {
            app.launchArguments += ["resetData"]
        }
        app.launchArguments += ["testing"]
        app.launchArguments += ["-AppleLanguages", "(en-GB)"]
        app.launchArguments += ["-AppleLocale", "en_GB"]
        app.launchArguments += ["-photos_access_allowed", "YES"]
        app.launch()
        login()
    }

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test
        // method.
        app = XCUIApplication()
    }

    override func tearDown() {
        guard let currentName else { return }
        print("Deleting \(currentName)")
        tearDownTest(directoryName: currentName)
    }

    func wait(delay: TimeInterval = 5) {
        let delayExpectation = XCTestExpectation()
        delayExpectation.isInverted = true
        wait(for: [delayExpectation], timeout: delay)
    }

    func goToMyFolders() {
        openTab(.files)
        collectionViewsQuery.cells.containing(
            .staticText,
            identifier: KDriveResourcesStrings.Localizable.localizedFilenamePrivateTeamSpace
        ).element.tap()
        sortByLatest()
    }

    func goToFavorites() {
        openTab(.files)
        collectionViewsQuery.cells.containing(
            .staticText,
            identifier: KDriveResourcesStrings.Localizable.favoritesTitle
        ).element.tap()
    }

    // MARK: - Tests setup

    func testLogin() {
        currentName = nil
        launchAppFromScratch()
    }

    func setUpTest(testName: String) -> String {
        return createDirectory(name: testName)
    }

    func tearDownTest(directoryName: String) {
        goToMyFolders()
        removeDirectory(name: directoryName)
    }

    // MARK: - Helping methods

    func createDirectory(name: String) -> String {
        openTab(.add)
        let folderCell = tablesQuery.cells.containing(.staticText, identifier: KDriveResourcesStrings.Localizable.allFolder)
            .element
        folderCell.tap()
        folderCell.tap()

        let folderTextField = tablesQuery.textFields[KDriveResourcesStrings.Localizable.hintInputDirName]
        folderTextField.tap()
        folderTextField.tap()
        folderTextField.typeText(name)
        tablesQuery.buttons[KDriveResourcesStrings.Localizable.buttonCreateFolder].tap()
        openTab(.files)

        XCTAssertTrue(tabBar.buttons[getStringForElement(.files)].waitForExistence(timeout: 5), "Waiting for folder creation")

        return name
    }

    func createDirectoryWithPhoto(name: String) -> String {
        let directory = createDirectory(name: name)
        enterInDirectory(named: directory)

        // Import photo from photo library
        openTab(.add)
        tablesQuery.staticTexts[KDriveResourcesStrings.Localizable.buttonUploadPhotoOrVideo].tap()
        let springboardApp = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let acceptAllButton = springboardApp.buttons.element(boundBy: 1).firstMatch
        if acceptAllButton.exists {
            acceptAllButton.tap()
        }
        let photospickerApp = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow.photospicker")
        XCTAssertGreaterThan(photospickerApp.images.debugDescription.count, 1, "No photos in photo library")
        photospickerApp.images.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        photospickerApp.buttons[KDriveResourcesStrings.Localizable.buttonAdd].firstMatch.tap()

        let buttonSave = app.buttons[KDriveResourcesStrings.Localizable.buttonSave]
        XCTAssertTrue(buttonSave.waitForExistence(timeout: 4), "Save button should be displayed")
        buttonSave.tap()
        return directory
    }

    func removeDirectory(name: String) {
        goToMyFolders()
        collectionViewsQuery.cells.containing(.staticText, identifier: name).element.press(forDuration: 1)
        let deleteButton = collectionViewsQuery.buttons[KDriveResourcesStrings.Localizable.buttonDelete]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button should be displayed")
        deleteButton.tap()
        app.buttons.containing(.staticText, identifier: KDriveResourcesStrings.Localizable.buttonMove).element.tap()
    }

    func openFileMenu(named name: String, fullSize: Bool = false) {
        goToMyFolders()
        let file = collectionViewsQuery.cells.containing(.staticText, identifier: name)
        XCTAssertTrue(file.element.waitForExistence(timeout: 5), "File should be displayed")
        file.buttons[KDriveResourcesStrings.Localizable.buttonMenu].tap()
        if fullSize {
            app.swipeUp()
        }
    }

    func sortByLatest() {
        wait(delay: 0.5)
        if app.buttons[KDriveResourcesStrings.Localizable.sortNameAZ].firstMatch.exists {
            app.buttons[KDriveResourcesStrings.Localizable.sortNameAZ].firstMatch.tap()
            wait(delay: 1)
            app.staticTexts[KDriveResourcesStrings.Localizable.sortRecent].firstMatch.tap()
        }
        XCTAssertTrue(
            app.staticTexts[KDriveResourcesStrings.Localizable.sortRecent].firstMatch.waitForExistence(timeout: 5),
            "Should be sorted by most recent"
        )
    }

    func closeFileMenu() {
        app.swipeDown()
        app.tap()
    }

    func enterInDirectory(named name: String) {
        goToMyFolders()
        collectionViewsQuery.cells.containing(.staticText, identifier: name).element.tap()
    }

    func shareWithMail(address mail: String) {
        let emailTextField = tablesQuery.textFields[KDriveResourcesStrings.Localizable.shareFileInputUserAndEmail]
        XCTAssertTrue(emailTextField.waitForExistence(timeout: 3), "Email text field should be displayed")
        emailTextField.tap()
        emailTextField.typeText(mail)
        let dropdownMail = app.otherElements["drop_down"].staticTexts[mail]
        XCTAssertTrue(dropdownMail.waitForExistence(timeout: 3), "Dropdown mail should be displayed")
        dropdownMail.tap()
        let shareButton = tablesQuery.buttons[KDriveResourcesStrings.Localizable.buttonShare]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 3), "Share button should be displayed")
        shareButton.tap()
    }

    func openTab(_ element: TabBarElement) {
        tabBar.buttons[getStringForElement(element)].tap()
    }

    // MARK: - Structures

    enum TabBarElement {
        case home, files, add, gallery, menu
    }

    // MARK: - Tests methods

    func testRenameFile() {
        let testName = "UITest - Rename file-\(Date())"
        let newTestName = "\(testName)_update"
        currentName = newTestName
        launchAppFromScratch()

        let laterButton = app.buttons[KDriveResourcesStrings.Localizable.buttonLater]
        if laterButton.exists {
            laterButton.tap()
        }
        let root = setUpTest(testName: testName)

        // Open sheet with file details
        openFileMenu(named: root, fullSize: true)

        // Rename file
        let rename = collectionViewsQuery.staticTexts[KDriveResourcesStrings.Localizable.buttonRename]
        XCTAssertTrue(rename.waitForExistence(timeout: 4), "Rename text should be displayed")
        rename.tap()
        let fileNameTextField = app.textFields[KDriveResourcesStrings.Localizable.hintInputDirName]
        XCTAssertTrue(fileNameTextField.waitForExistence(timeout: 3), "Filename textfield should be displayed")
        var deleteString = String()
        for _ in newTestName {
            deleteString += XCUIKeyboardKey.delete.rawValue
        }
        fileNameTextField.typeText(deleteString)
        fileNameTextField.typeText(newTestName)
        app.buttons[KDriveResourcesStrings.Localizable.buttonSave].tap()
        XCTAssertTrue(rename.waitForExistence(timeout: 4), "Rename should be visible after closing the dialog box")

        // Check new name
        closeFileMenu()
        XCTAssertTrue(app.staticTexts[newTestName].exists, "File must be renamed")
    }

    func testDuplicateFile() {
        let testName = "UITest - Duplicate file - \(Date())"
        launchAppFromScratch()
        let root = setUpTest(testName: testName)
        currentName = root

        openFileMenu(named: root, fullSize: true)

        let duplicateButton = collectionViewsQuery.staticTexts[KDriveResourcesStrings.Localizable.buttonDuplicate]
        XCTAssertTrue(duplicateButton.waitForExistence(timeout: 2), "Duplicate button should be displayed")
        duplicateButton.tap()
        let myFolder = collectionViewsQuery.cells.containing(
            .staticText,
            identifier: KDriveResourcesStrings.Localizable.localizedFilenamePrivateTeamSpace
        ).element
        XCTAssertTrue(myFolder.waitForExistence(timeout: 2), "My Folder button should be displayed")
        myFolder.tap()
        let selectButton = app.buttons[KDriveResourcesStrings.Localizable.buttonSelectTheFolder]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 2), "Select Folder button should be displayed")
        selectButton.tap()
        wait(delay: 2)
        XCTAssertTrue(app.staticTexts[root].exists, "File should exist")
        let duplicatedFile = "\(root) (1)"
        XCTAssertTrue(app.staticTexts[duplicatedFile].waitForExistence(timeout: 5), "Duplicated file should exist")

        removeDirectory(name: duplicatedFile)
        XCTAssertTrue(app.staticTexts[root].waitForExistence(timeout: 3), "Dialog box should be dismissed")
    }

    func testShareFile() {
        let testName = "UITest - Share file - \(Date())"
        launchAppFromScratch()
        let root = setUpTest(testName: testName)
        currentName = root

        openFileMenu(named: root)
        let shareAndRights = collectionViewsQuery.cells.staticTexts[KDriveResourcesStrings.Localizable.buttonFileRights]
        shareAndRights.tap()
        let directoryShareAndRights = app.navigationBars[KDriveResourcesStrings.Localizable.fileShareDetailsFolderTitle(root)]
        XCTAssertTrue(directoryShareAndRights.waitForExistence(timeout: 3), "Share view should be displayed")

        // Share file by email
        let userMail = "kdriveiostests+uitest@ik.me"
        shareWithMail(address: userMail)
        let closeButton = app.buttons[KDriveResourcesStrings.Localizable.buttonClose]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Close button should be visible")
        closeButton.tap()

        // Check rights
        openFileMenu(named: root)
        shareAndRights.tap()
        XCTAssertTrue(directoryShareAndRights.waitForExistence(timeout: 3), "Share view should be displayed")
        XCTAssertTrue(app.staticTexts[userMail].exists, "Invited user should be displayed")

        // Remove user
        let canAccessButton = tablesQuery.staticTexts[KDriveResourcesStrings.Localizable.userPermissionRead]
        XCTAssertTrue(canAccessButton.waitForExistence(timeout: 10), "Sharing choices should be displayed")
        canAccessButton.tap()
        app.staticTexts[KDriveResourcesStrings.Localizable.buttonRemoveUserFromShare].tap()
        app.buttons[KDriveResourcesStrings.Localizable.buttonDelete].tap()
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Close button should be visible")
        closeButton.tap()

        collectionViewsQuery.cells.containing(.staticText, identifier: root).element.swipeLeft()
        collectionViewsQuery.buttons[KDriveResourcesStrings.Localizable.buttonFileRights].firstMatch.tap()

        // Check number of cells
        XCTAssertTrue(tablesQuery.cells.firstMatch.waitForExistence(timeout: 3), "Cells should be displayed")
        XCTAssertFalse(app.staticTexts[userMail].exists, "Invited user should not be displayed")
        app.buttons[KDriveResourcesStrings.Localizable.buttonClose].tap()
    }

    func testComments() {
        let testName = "UITest - Comment - \(Date())"
        launchAppFromScratch()
        goToMyFolders()
        let root = createDirectoryWithPhoto(name: testName)
        currentName = root

        // Open Information sheet about imported photo
        let imageCell = collectionViewsQuery.cells.firstMatch
        XCTAssertTrue(imageCell.waitForExistence(timeout: 10), "Image should be imported")
        imageCell.buttons[KDriveResourcesStrings.Localizable.buttonMenu].tap()
        collectionViewsQuery.cells.staticTexts[KDriveResourcesStrings.Localizable.fileDetailsInfosTitle].tap()

        // Add new comment
        tablesQuery.buttons[KDriveResourcesStrings.Localizable.fileDetailsCommentsTitle].tap()
        app.buttons[KDriveResourcesStrings.Localizable.buttonAddComment].tap()
        let comment = "UITest comment"
        app.typeText(comment)
        app.buttons[KDriveResourcesStrings.Localizable.buttonSend].tap()

        XCTAssertTrue(tablesQuery.staticTexts[comment].waitForExistence(timeout: 5), "Comment should exist")

        // Update comment
        tablesQuery.cells.containing(.staticText, identifier: "John Appleseed").element.swipeLeft()
        tablesQuery.buttons[KDriveResourcesStrings.Localizable.buttonEdit].tap()
        app.typeText("-Update")
        app.buttons[KDriveResourcesStrings.Localizable.buttonSave].tap()

        XCTAssertTrue(tablesQuery.staticTexts["\(comment)-Update"].waitForExistence(timeout: 5), "New comment should exist")

        // Back to drive's root
        tablesQuery.buttons[KDriveResourcesStrings.Localizable.fileDetailsInfosTitle].tap()
        app.swipeUp()
        tablesQuery.buttons[KDriveResourcesStrings.Localizable.allPathTitle].tap()
        navigationBars.buttons.element(boundBy: 0).tap()
        navigationBars.buttons.element(boundBy: 0).tap()
        navigationBars.buttons.element(boundBy: 0).tap()
    }

    func testCreateSharedDirectory() {
        let testName = "UITest - Create shared directory"
        launchAppFromScratch()
        // Create shared directory
        let root = "\(testName)-\(Date())"
        currentName = root

        openTab(.files)
        openTab(.add)
        let folderCell = tablesQuery.cells.containing(.staticText, identifier: KDriveResourcesStrings.Localizable.allFolder)
            .element
        folderCell.tap()
        folderCell.tap()
        let folderTextField = tablesQuery.textFields[KDriveResourcesStrings.Localizable.hintInputDirName]
        folderTextField.tap()
        folderTextField.typeText(root)
        app.buttons[KDriveResourcesStrings.Localizable.buttonCreateFolder].tap()
        openFileMenu(named: root)
        let shareButton = collectionViewsQuery.cells.staticTexts[KDriveResourcesStrings.Localizable.buttonFileRights]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 3), "Share button sould be displayed")
        shareButton.tap()
        // Invite user with mail
        let userMail = "kdriveiostests+uitest@ik.me"
        shareWithMail(address: userMail)
        let closeButton = app.buttons[KDriveResourcesStrings.Localizable.buttonClose]
        closeButton.tap()

        // Check share rights
        openFileMenu(named: root)
        XCTAssertTrue(shareButton.waitForExistence(timeout: 3), "Share button sould be displayed")
        shareButton.tap()
        XCTAssertTrue(
            tablesQuery.cells.containing(.staticText, identifier: "John Appleseed").element.waitForExistence(timeout: 5),
            "John Appleseed should have access to file"
        )
        XCTAssertTrue(
            tablesQuery.cells.containing(.staticText, identifier: userMail).element.exists,
            "Invited user should have access to file"
        )
        app.buttons[KDriveResourcesStrings.Localizable.buttonClose].tap()
    }

    func testCreateOfficeFile() {
        let testName = "UITest - Create office file - \(Date())"
        launchAppFromScratch()
        let root = setUpTest(testName: testName)
        currentName = root

        // Enter in root directory
        enterInDirectory(named: root)

        // Create office file
        openTab(.add)
        tablesQuery.staticTexts[KDriveResourcesStrings.Localizable.allOfficeDocs].tap()
        app.typeText("UITest - Office file")
        app.buttons[KDriveResourcesStrings.Localizable.buttonCreate].tap()

        // Leave office edition page
        let officeBackButton = app.images.element(boundBy: 5)
        XCTAssertTrue(officeBackButton.waitForExistence(timeout: 10), "back button should be displayed")
        sleep(6)
        officeBackButton.tap()

        openTab(.files)
    }

    func testOfflineFiles() {
        let testName = "UITest - Offline files - \(Date())"
        launchAppFromScratch()

        // Get number of offline files
        goToMyFolders()

        openTab(.files)

        let root = createDirectoryWithPhoto(name: testName)
        currentName = root

        // Open Information sheet about imported photo
        collectionViewsQuery.cells.firstMatch.buttons[KDriveResourcesStrings.Localizable.buttonMenu].tap()
        app.swipeUp()
        let switchOffline = collectionViewsQuery.switches["0"]
        XCTAssertTrue(switchOffline.waitForExistence(timeout: 3), "Switch should be displayed")
        switchOffline.tap()
        wait(delay: 2)
        app.swipeDown()
        wait(delay: 1)
        app.tap()

        // Go to offline files
        openTab(.files)
        collectionViewsQuery.cells.containing(
            .staticText,
            identifier: KDriveResourcesStrings.Localizable.offlineFileTitle
        ).element.tap()

        XCTAssertTrue(app.staticTexts.count.signum() == 1)

        openTab(.files)
    }

    func testCancelAction() {
        let testName = "UITest - Cancel action - \(Date())"
        launchAppFromScratch()
        let root = createDirectoryWithPhoto(name: testName)
        currentName = root

        wait(delay: 1)
        openFileMenu(named: root, fullSize: true)
        let delete = app.staticTexts[KDriveResourcesStrings.Localizable.modalMoveTrashTitle].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 4), "Rename text should be displayed")
        delete.tap()
        app.buttons[KDriveResourcesStrings.Localizable.buttonMove].firstMatch.tap()
        app.buttons[KDriveResourcesStrings.Localizable.buttonCancel].tap()

        app.staticTexts[testName].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["20180330_211419_3650.jpeg"].waitForExistence(timeout: 3),
            "Photo should be back in directory"
        )
    }

    func testAddFileToFavorites() {
        let testName = "UITest - Add file to favorites - \(Date())"
        launchAppFromScratch()
        let root = setUpTest(testName: testName)
        currentName = root

        goToMyFolders()

        // Add directory to favorites
        collectionViewsQuery.cells.containing(.staticText, identifier: root).element.press(forDuration: 1)
        collectionViewsQuery.buttons[KDriveResourcesStrings.Localizable.buttonMenu].tap()
        let favoriteButton = collectionViewsQuery.staticTexts[KDriveResourcesStrings.Localizable.buttonAddFavorites]
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 3), "Favorite button should be displayed")
        favoriteButton.tap()

        // Check file in favorites page
        goToFavorites()
        XCTAssertTrue(app.staticTexts[root].waitForExistence(timeout: 3), "Directory should be in favorites")
    }

    func testSearchFile() {
        let testName = "UITest - Search file - \(Date())"
        launchAppFromScratch()
        let root = setUpTest(testName: testName)
        currentName = root

        openTab(.home)
        app.buttons[KDriveResourcesStrings.Localizable.searchTitle].firstMatch.tap()
        app.searchFields[KDriveResourcesStrings.Localizable.searchViewHint].tap()
        app.typeText(testName)
        app.typeText("\n")

        XCTAssertTrue(app.staticTexts.count >= 1, "Directory should be listed in results")

        navigationBars[KDriveResourcesStrings.Localizable.searchTitle].buttons[KDriveResourcesStrings.Localizable.buttonClose]
            .tap()
    }

    func testAddCategories() {
        let testName = "UITest - Add categories - \(Date())"
        launchAppFromScratch()

        let root = setUpTest(testName: testName)
        currentName = root

        // Add category
        openFileMenu(named: root, fullSize: true)
        let categoriesButton = collectionViewsQuery.staticTexts[KDriveResourcesStrings.Localizable.manageCategoriesTitle]
        XCTAssertTrue(categoriesButton.waitForExistence(timeout: 3), "Categories button should be displayed")
        categoriesButton.tap()
        tablesQuery.cells.firstMatch.tap()
        navigationBars.buttons[KDriveResourcesStrings.Localizable.buttonClose].tap()
        closeFileMenu()

        // Search file with filter category
        navigationBars.buttons[KDriveResourcesStrings.Localizable.searchTitle].tap()
        navigationBars.buttons.element(boundBy: 1).tap()
        wait(delay: 0.5)
        tablesQuery.staticTexts[KDriveResourcesStrings.Localizable.addCategoriesTitle].tap()
        tablesQuery.cells.firstMatch.tap()
        let value = KDriveResourcesStrings.Localizable.buttonBack != "Back" ? KDriveResourcesStrings.Localizable.buttonBack : "BackButton"
        app.buttons[value].firstMatch.tap()
        app.staticTexts[KDriveResourcesStrings.Localizable.buttonApplyFilters].firstMatch.tap()
        XCTAssertTrue(app.staticTexts[root].waitForExistence(timeout: 4), "Directory with category should be in result")
        navigationBars.buttons[KDriveResourcesStrings.Localizable.buttonClose].tap()
    }

    func login() {
        app.buttons[KDriveResourcesStrings.Localizable.buttonNext].firstMatch.tap()
        app.buttons[KDriveResourcesStrings.Localizable.buttonNext].firstMatch.tap()

        let loginButton = app.buttons.element(boundBy: 0)
        _ = loginButton.waitForExistence(timeout: defaultTimeOut)
        loginButton.tap()
        let loginWebView = app.webViews.firstMatch

        let emailField = loginWebView.textFields.firstMatch
        _ = emailField.waitForExistence(timeout: defaultTimeOut)
        emailField.tap()
        emailField.typeText(Env.testAccountEmail)

        let passwordField = loginWebView.secureTextFields.firstMatch
        passwordField.tap()
        passwordField.typeText(Env.testAccountPassword)
        passwordField.typeText("\n")

        wait(delay: 5)
        XCTAssertTrue(
            app.buttons[KDriveResourcesStrings.Localizable.fileListTitle].waitForExistence(timeout: 5),
            "Last modification text should display"
        )
    }

    func getStringForElement(_ element: TabBarElement) -> String {
        switch element {
        case .home:
            return KDriveResourcesStrings.Localizable.homeTitle
        case .files:
            return KDriveResourcesStrings.Localizable.fileListTitle
        case .add:
            return KDriveResourcesStrings.Localizable.buttonAdd
        case .gallery:
            return KDriveResourcesStrings.Localizable.galleryTitle
        case .menu:
            return KDriveResourcesStrings.Localizable.menuTitle
        }
    }
}
