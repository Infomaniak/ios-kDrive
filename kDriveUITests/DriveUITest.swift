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
import XCTest

class AppUITest: XCTestCase {
    var app: XCUIApplication!

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

    static let defaultTimeout = 50.0

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test
        // method.
        app = XCUIApplication()
        app.launchArguments = ["testing"]
        app.launchArguments += ["-AppleLanguages", "(fr)"]
        app.launchArguments += ["-AppleLocale", "fr_FR"]
        app.launch()
    }

    // MARK: - Tests setup

    func setUpTest(testName: String) -> String {
        return createDirectory(name: testName)
    }

    func tearDownTest(directoryName: String) {
        removeDirectory(name: directoryName)
    }

    // MARK: - Helping methods

    func createDirectory(name: String) -> String {
        openTab(.add)
        let folderCell = tablesQuery.cells.containing(.staticText, identifier: "Dossier").element
        folderCell.tap()
        folderCell.tap()

        let folderTextField = tablesQuery.textFields["Nom du dossier"]
        folderTextField.tap()
        folderTextField.tap()
        let folderName = "\(name)-\(Date())"
        folderTextField.typeText(folderName)

        let meOnly = tablesQuery.staticTexts["Moi uniquement"]
        meOnly.tap()
        tablesQuery.buttons["Créer le dossier"].tap()

        XCTAssertTrue(tabBar.buttons["Fichiers"].waitForExistence(timeout: 5), "Waiting for folder creation")
        return folderName
    }

    func createDirectoryWithPhoto(name: String) -> String {
        let directory = createDirectory(name: name)

        openTab(.files)
        enterInDirectory(named: directory)

        // Import photo from photo library
        openTab(.add)
        tablesQuery.staticTexts["Importer une photo ou une vidéo"].tap()
        let imageToImport = app.scrollViews.images.element(boundBy: 0)
        XCTAssertTrue(imageToImport.waitForExistence(timeout: 4), "Images should be displayed")
        imageToImport.tap()
        navigationBars["Photos"].buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["IMG_0111.heic"].waitForExistence(timeout: 10), "Image should be imported")

        return directory
    }

    func removeDirectory(name: String) {
        collectionViewsQuery.cells.containing(.staticText, identifier: name).element.press(forDuration: 1)
        let deleteButton = collectionViewsQuery.buttons["Supprimer"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button should be displayed")
        deleteButton.tap()
        app.buttons.containing(.staticText, identifier: "Déplacer").element.tap()
    }

    func openFileMenu(named name: String, fullSize: Bool = false) {
        let file = collectionViewsQuery.cells.containing(.staticText, identifier: name)
        XCTAssertTrue(file.element.waitForExistence(timeout: 5), "File should be displayed")
        file.buttons["Menu"].tap()
        if fullSize {
            app.swipeUp()
        }
    }

    func closeFileMenu() {
        app.swipeDown()
        app.navigationBars.firstMatch.coordinate(withNormalizedOffset: .zero).tap()
    }

    func enterInDirectory(named name: String) {
        collectionViewsQuery.cells.containing(.staticText, identifier: name).element.tap()
    }

    func shareWithMail(address mail: String) {
        let emailTextField = tablesQuery.textFields["Invitez un utilisateur ou une adresse mail…"]
        XCTAssertTrue(emailTextField.waitForExistence(timeout: 3), "Email text field should be displayed")
        emailTextField.tap()
        emailTextField.typeText(mail)
        let dropdownMail = app.otherElements["drop_down"].staticTexts[mail]
        XCTAssertTrue(dropdownMail.waitForExistence(timeout: 3), "Dropdown mail should be displayed")
        dropdownMail.tap()
        let shareButton = tablesQuery.buttons["Partager"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 3), "Share button should be displayed")
        shareButton.tap()
    }

    func openTab(_ element: TabBarElement) {
        tabBar.buttons[element.rawValue].tap()
    }

    // MARK: - Structures

    enum TabBarElement: String {
        case home = "Accueil"
        case files = "Fichiers"
        case add = "Ajouter"
        case favorites = "Favoris"
    }

    // MARK: - Tests methods

    func testRenameFile() {
        let testName = "UITest - Rename file"

        let root = setUpTest(testName: testName)
        openTab(.files)

        // Open sheet with file details
        openFileMenu(named: root, fullSize: true)

        // Rename file
        let rename = collectionViewsQuery.staticTexts["Renommer"]
        XCTAssertTrue(rename.waitForExistence(timeout: 4), "Rename text should be displayed")
        rename.tap()
        let fileNameTextField = app.textFields["Nom du dossier"]
        XCTAssertTrue(fileNameTextField.waitForExistence(timeout: 3), "Filename textfield should be displayed")
        fileNameTextField.tap()
        fileNameTextField.typeText("_update")
        let newName = "\(root)_update"
        app.buttons["Enregistrer"].tap()
        XCTAssertTrue(rename.waitForExistence(timeout: 4), "Rename should be visible after closing the dialog box")

        // Check new name
        closeFileMenu()
        XCTAssertTrue(app.staticTexts[newName].exists, "File must be renamed")

        tearDownTest(directoryName: newName)
    }

    func testDuplicateFile() {
        let testName = "UITest - Duplicate file"

        let root = setUpTest(testName: testName)
        openTab(.files)

        openFileMenu(named: root, fullSize: true)

        let duplicateButton = collectionViewsQuery.staticTexts["Dupliquer"]
        XCTAssertTrue(duplicateButton.waitForExistence(timeout: 2), "Duplicate button should be displayed")
        duplicateButton.tap()
        let copyButton = app.buttons["Copier"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 2), "Copy button should be displayed")
        copyButton.tap()
        closeFileMenu()
        XCTAssertTrue(app.staticTexts[root].exists, "File should exist")
        let duplicatedFile = "\(root) - Copie"
        XCTAssertTrue(app.staticTexts[duplicatedFile].exists, "Duplicated file should exist")

        removeDirectory(name: duplicatedFile)
        XCTAssertTrue(app.staticTexts[root].waitForExistence(timeout: 3), "Dialog box should be dismissed")
        tearDownTest(directoryName: root)
    }

    func testShareFile() {
        let testName = "UITest - Share file"

        let root = setUpTest(testName: testName)
        openTab(.files)

        openFileMenu(named: root)
        let shareAndRights = collectionViewsQuery.cells.staticTexts["Partage et droits"]
        shareAndRights.tap()
        let directoryShareAndRights = app.navigationBars["Partage et droits du dossier \(root)"]
        XCTAssertTrue(directoryShareAndRights.waitForExistence(timeout: 3), "Share view should be displayed")

        // Share file by email
        let userMail = "kdriveiostests+uitest@ik.me"
        shareWithMail(address: userMail)
        let closeButton = app.buttons["Fermer"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Close button should be visible")
        closeButton.tap()

        // Check rights
        openFileMenu(named: root)
        shareAndRights.tap()
        XCTAssertTrue(directoryShareAndRights.waitForExistence(timeout: 3), "Share view should be displayed")
        XCTAssertTrue(app.staticTexts[userMail].exists, "Invited user should be displayed")

        // Remove user
        let canAccessButton = tablesQuery.staticTexts["Peut consulter"]
        XCTAssertTrue(canAccessButton.waitForExistence(timeout: 10), "Sharing choices should be displayed")
        canAccessButton.tap()
        app.staticTexts["Supprimer"].tap()
        app.buttons["Supprimer"].tap()
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Close button should be visible")
        closeButton.tap()

        collectionViewsQuery.cells.containing(.staticText, identifier: root).element.swipeLeft()
        collectionViewsQuery.buttons["Partage et droits"].tap()

        // Check number of cells
        XCTAssertTrue(tablesQuery.cells.firstMatch.waitForExistence(timeout: 3), "Cells should be displayed")
        XCTAssertFalse(app.staticTexts[userMail].exists, "Invited user should not be displayed")
        app.buttons["Fermer"].tap()

        tearDownTest(directoryName: root)
    }

    func testComments() {
        let testName = "UITest - Comment"

        let root = createDirectoryWithPhoto(name: testName)

        // Open Information sheet about imported photo
        let imageCell = collectionViewsQuery.cells.firstMatch
        XCTAssertTrue(imageCell.waitForExistence(timeout: 10), "Image should be imported")
        imageCell.buttons["Menu"].tap()
        collectionViewsQuery.cells.staticTexts["Informations"].tap()

        // Add new comment
        tablesQuery.buttons["Commentaires"].tap()
        app.buttons["Ajouter un commentaire"].tap()
        let comment = "UITest comment"
        app.typeText(comment)
        app.buttons["Envoyer"].tap()

        XCTAssertTrue(tablesQuery.staticTexts[comment].waitForExistence(timeout: 5), "Comment should exist")

        // Update comment
        tablesQuery.cells.containing(.staticText, identifier: "John Appleseed").element.swipeLeft()
        tablesQuery.buttons["Éditer"].tap()
        app.typeText("-Update")
        app.buttons["Enregistrer"].tap()

        XCTAssertTrue(tablesQuery.staticTexts["\(comment)-Update"].waitForExistence(timeout: 5), "New comment should exist")

        // Back to drive's root
        tablesQuery.buttons["Informations"].tap()
        app.swipeUp()
        tablesQuery.buttons["Emplacement"].tap()
        navigationBars.buttons.element(boundBy: 0).tap()
        navigationBars.buttons.element(boundBy: 0).tap()
        navigationBars.buttons.element(boundBy: 0).tap()

        tearDownTest(directoryName: root)
    }

    func testCreateSharedDirectory() {
        let testName = "UITest - Create shared directory"

        // Create shared directory
        let root = "\(testName)-\(Date())"
        openTab(.files)
        openTab(.add)
        let folderCell = tablesQuery.cells.containing(.staticText, identifier: "Dossier").element
        folderCell.tap()
        folderCell.tap()
        let folderTextField = tablesQuery.textFields["Nom du dossier"]
        folderTextField.tap()
        folderTextField.typeText(root)
        tablesQuery.staticTexts["Certains utilisateurs"].tap()
        tablesQuery.staticTexts["Certains utilisateurs"].tap()
        app.buttons["Créer le dossier"].tap()

        // Invite user with mail
        let userMail = "kdriveiostests+uitest@ik.me"
        shareWithMail(address: userMail)
        app.buttons["Fermer"].tap()

        // Check share rights
        openFileMenu(named: root)
        let shareButton = collectionViewsQuery.cells.staticTexts["Partage et droits"]
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
        app.buttons["Fermer"].tap()

        tearDownTest(directoryName: root)
    }

    func testCreateOfficeFile() {
        let testName = "UITest - Create office file"

        let root = setUpTest(testName: testName)

        // Enter in root directory
        openTab(.files)
        enterInDirectory(named: root)

        // Create office file
        openTab(.add)
        tablesQuery.staticTexts["Document"].tap()
        app.typeText("UITest - Office file")
        app.buttons["Créer"].tap()

        // Leave office edition page
        let officeBackButton = app.webViews.staticTexts["chevron_left_ios"]
        XCTAssertTrue(officeBackButton.waitForExistence(timeout: 4), "back button should be displayed")
        sleep(6)
        officeBackButton.tap()

        openTab(.files)
        tearDownTest(directoryName: root)
    }

    func testOfflineFiles() {
        let testName = "UITest - Offline files"

        // Get number of offline files
        openTab(.home)
        collectionViewsQuery.buttons["Hors ligne"].tap()

        let root = createDirectoryWithPhoto(name: testName)

        // Open Information sheet about imported photo
        collectionViewsQuery.cells.firstMatch.buttons["Menu"].tap()
        app.swipeUp()
        let switchOffline = collectionViewsQuery.switches["0"]
        XCTAssertTrue(switchOffline.waitForExistence(timeout: 3), "Switch should be displayed")
        switchOffline.tap()
        closeFileMenu()

        // Go to offline files
        openTab(.home)
        collectionViewsQuery.buttons["Hors ligne"].tap()

        // Refresh table
        let firstCell = collectionViewsQuery.cells.firstMatch
        let start = firstCell.coordinate(withNormalizedOffset: .zero)
        let finish = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 10))
        start.press(forDuration: 0, thenDragTo: finish)
        XCTAssertTrue(app.staticTexts["IMG_0111.heic"].waitForExistence(timeout: 10), "Image should be available offline")

        openTab(.files)
        openTab(.files)
        tearDownTest(directoryName: root)
    }

    func testCancelAction() {
        let testName = "UITest - Cancel action"

        let root = createDirectoryWithPhoto(name: testName)

        // Remove image
        collectionViewsQuery.cells.firstMatch.swipeLeft()
        app.buttons["Supprimer"].tap()
        XCTAssertTrue(app.staticTexts["Annuler"].waitForExistence(timeout: 2), "Cancel button should be displayed")

        app.buttons["Annuler"].tap()
        XCTAssertTrue(app.staticTexts["IMG_0111.heic"].waitForExistence(timeout: 3), "Photo should be back in directory")

        openTab(.files)
        tearDownTest(directoryName: root)
    }

    func testAddFileToFavorites() {
        let testName = "UITest - Add file to favorites"

        let root = setUpTest(testName: testName)
        openTab(.files)

        // Add directory to favorites
        collectionViewsQuery.cells.containing(.staticText, identifier: root).element.press(forDuration: 1)
        collectionViewsQuery.buttons["Menu"].tap()
        let favoriteButton = collectionViewsQuery.staticTexts["Ajouter aux favoris"]
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 3), "Favorite button should be displayed")
        favoriteButton.tap()

        // Check file in favorites page
        openTab(.favorites)
        XCTAssertTrue(app.staticTexts[root].waitForExistence(timeout: 3), "Directory should be in favorites")

        openTab(.files)
        tearDownTest(directoryName: root)
    }

    func testSearchFile() {
        let testName = "UITest - Search file"

        let root = setUpTest(testName: testName)

        openTab(.home)
        collectionViewsQuery.staticTexts["Rechercher un fichier…"].tap()
        app.searchFields["Rechercher un fichier…"].tap()
        app.typeText(testName)

        XCTAssertTrue(app.staticTexts[root].waitForExistence(timeout: 4), "Directory should be listed in results")

        navigationBars["Rechercher"].buttons["Fermer"].tap()

        openTab(.files)
        tearDownTest(directoryName: root)
    }

    func testAddCategories() {
        let testName = "UITest - Add categories"

        let root = setUpTest(testName: testName)
        openTab(.files)

        // Add category
        openFileMenu(named: root, fullSize: true)
        let categoriesButton = collectionViewsQuery.staticTexts["Gérer les catégories"]
        XCTAssertTrue(categoriesButton.waitForExistence(timeout: 3), "Categories button should be displayed")
        categoriesButton.tap()
        tablesQuery.cells.firstMatch.tap()
        navigationBars.buttons["Fermer"].tap()
        closeFileMenu()

        // Search file with filter category
        navigationBars.buttons["Rechercher"].tap()
        navigationBars.buttons.element(boundBy: 1).tap()
        tablesQuery.staticTexts["Ajouter des catégories"].tap()
        tablesQuery.cells.firstMatch.tap()
        navigationBars.buttons["Filtres"].tap()
        tablesQuery.staticTexts["Appliquer les filtres"].tap()

        XCTAssertTrue(app.staticTexts[root].waitForExistence(timeout: 4), "Directory with category should be in result")
        navigationBars.buttons["Fermer"].tap()

        tearDownTest(directoryName: root)
    }
}
