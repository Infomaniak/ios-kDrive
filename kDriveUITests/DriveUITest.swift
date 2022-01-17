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

import XCTest
import kDriveCore

class AppUITest: XCTestCase {
    var app: XCUIApplication!

    var tabBar: XCUIElementQuery {
        return app.tabBars
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

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        app.launchArguments = ["testing"]
        app.launchArguments += ["-AppleLanguages", "(fr)"]
        app.launchArguments += ["-AppleLocale", "fr_FR"]
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
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
        tabBar.buttons["Ajouter"].tap()
        let folderCell = tablesQuery.cells.containing(.staticText, identifier: "Dossier").element
        folderCell.tap()
        folderCell.tap()

        let folderTextField = tablesQuery.textFields["Nom du dossier"]
        folderTextField.tap()
        let folderName = "\(name)-\(Date())"
        folderTextField.typeText(folderName)

        let meOnly = tablesQuery.staticTexts["Moi uniquement"]
        meOnly.tap()
        tablesQuery.buttons["Créer le dossier"].tap()

        XCTAssertTrue(tabBar.buttons["Fichiers"].waitForExistence(timeout: 5), "Waiting for folder creation")
        return folderName
    }

    func removeDirectory(name: String) {
        let folder = collectionViewsQuery.cells.containing(.staticText, identifier: name).element
        folder.press(forDuration: 1)
        collectionViewsQuery.buttons["Supprimer"].tap()
        app.buttons.containing(.staticText, identifier: "Déplacer").element.tap()
    }

    func openFileMenu(named name: String) {
        let file = collectionViewsQuery.cells.containing(.staticText, identifier: name)
        file.buttons["Menu"].tap()
    }

    func shareMailWithMail(address mail: String) {
        let emailTextField = tablesQuery.textFields["Invitez un utilisateur ou une adresse mail…"]
        emailTextField.tap()
        emailTextField.typeText(mail)
        XCTAssertTrue(app.otherElements["drop_down"].staticTexts[mail].exists, "Dropdown with mail should be present")
        app.otherElements.staticTexts[mail].tap()
        tablesQuery.buttons["Partager"].tap()
    }

    // MARK: - Tests methods

    func testRenameFile() {
        let testName = "UITest - Rename file"

        let root = setUpTest(testName: testName)
        tabBar.buttons["Fichiers"].tap()

        // Open sheet with file details
        openFileMenu(named: root)
        app.swipeUp()

        // Rename file
        sleep(2)
        collectionViewsQuery.staticTexts["Renommer"].tap()
        let fileNameTextField = app.textFields["Nom du dossier"]
        fileNameTextField .tap()
        fileNameTextField.typeText("_update")
        let newName = "\(root)_update"
        app.buttons["Enregistrer"].tap()
        sleep(1)

        // Check new name
        collectionViewsQuery.cells.staticTexts["Informations"].tap()
        XCTAssertTrue(app.staticTexts[newName].exists, "File must be renamed")

        // Return to files list
        tablesQuery.buttons["Emplacement"].tap()

        tearDownTest(directoryName: newName)
    }

    func testShareFile() {
        let testName = "UITest - Share file"

        let root = setUpTest(testName: testName)
        tabBar.buttons["Fichiers"].tap()

        openFileMenu(named: root)
        collectionViewsQuery.cells.staticTexts["Partage et droits"].tap()
        XCTAssertTrue(app.navigationBars["Partage et droits du dossier \(root)"].exists, "Share view should be displayed")

        // Check number of cells
        let cellsNumberBeforeSharing = tablesQuery.cells.count

        // Share file by email
        let emailTextField = tablesQuery/*@START_MENU_TOKEN@*/.textFields["Invitez un utilisateur ou une adresse mail…"]/*[[".cells.textFields[\"Invitez un utilisateur ou une adresse mail…\"]",".textFields[\"Invitez un utilisateur ou une adresse mail…\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        emailTextField.tap()
        let userMail = "kdriveiostests+uitest@ik.me"
        emailTextField.typeText(userMail)
        XCTAssertTrue(app.otherElements["drop_down"].staticTexts[userMail].exists, "Dropdown with mail should be present")
        app.otherElements.staticTexts[userMail].tap()
        tablesQuery.buttons["Partager"].tap()

        // Check number of cells
        let cellsNumberAfterSharing = tablesQuery.cells.count
        XCTAssertTrue(cellsNumberAfterSharing > cellsNumberBeforeSharing, "Number of cells should be greater after sharing")

        // Remove user
        XCTAssertTrue(tablesQuery.staticTexts["Peut consulter"].waitForExistence(timeout: 4), "Sharing choices should be displayed")
        tablesQuery.staticTexts["Peut consulter"].tap()
        app.staticTexts["Supprimer"].tap()
        app.buttons["Supprimer"].tap()
        sleep(2)
        app.buttons["Fermer"].tap()

        let fileCell = collectionViewsQuery.cells.containing(.staticText, identifier: root)
        fileCell.element.swipeLeft()
        collectionViewsQuery.buttons["Partage et droits"].tap()

        // Check number of cells
        let cellsNumberAfterRemoving = tablesQuery.cells.count
        XCTAssertTrue(cellsNumberBeforeSharing == cellsNumberAfterRemoving, "Number of cells should be equals after remo")
        app.buttons["Fermer"].tap()

        tearDownTest(directoryName: root)
    }

    func testComments() {
        let testName = "UITest - Comment"

        let root = setUpTest(testName: testName)
        tabBar.buttons["Fichiers"].tap()

        // Enter in folder
        let rootCell = collectionViewsQuery.cells.containing(.staticText, identifier: root).element
        rootCell.tap()

        // Import photo from photo library
        tabBar.buttons["Ajouter"].tap()
        tablesQuery.staticTexts["Importer une photo ou une vidéo"].tap()
        let imageToImport = app.scrollViews.images.element(boundBy: 0)
        XCTAssertTrue(imageToImport.waitForExistence(timeout: 4), "Images should be displayed")
        imageToImport.tap()
        app.navigationBars["Photos"].buttons["Add"].tap()

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
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        tearDownTest(directoryName: root)
    }

    func testCreateSharedDirectory() {
        let testName = "UITest - Create shared directory"

        // Create shared directory
        let root = "\(testName)-\(Date())"
        tabBar.buttons["Fichiers"].tap()
        tabBar.buttons["Ajouter"].tap()
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
        shareMailWithMail(address: userMail)
        app.buttons["Fermer"].tap()

        // Check share rights
        openFileMenu(named: root)
        collectionViewsQuery.cells.staticTexts["Partage et droits"].tap()
        XCTAssertTrue(tablesQuery.cells.containing(.staticText, identifier: "John Appleseed").element.waitForExistence(timeout: 5), "John Appleseed should have access to file")
        XCTAssertTrue(tablesQuery.cells.containing(.staticText, identifier: userMail).element.exists, "Invited user should have access to file")
        app.buttons["Fermer"].tap()

        tearDownTest(directoryName: root)
    }

//    func testCreateSharedFolder() {
//        let testName = "UITest CreateShareFolder"
//
//        let tablesQuery = app.tables
//        let collectionViewsQuery = app.collectionViews
//        let tabBar = app.tabBars
//
//        tabBar.buttons["Ajouter"].tap()
//        let folderCell = tablesQuery.cells.containing(.staticText, identifier: "Dossier").element
//        folderCell.tap()
//        folderCell.tap()
//
//        let folderTextField = tablesQuery.textFields["Nom du dossier"]
//        folderTextField.tap()
//        folderTextField.typeText("UITest CreateShareFolder")
//
//        let someUser = tablesQuery.staticTexts["Certains utilisateurs"]
//        XCTAssertTrue(someUser.exists, "Some user cell should exist")
//        someUser.tap()
//        someUser.tap()
//        tablesQuery.buttons["Créer le dossier"].tap()
//
//        XCTAssertTrue(app.navigationBars["Partage et droits du dossier \(testName)"].waitForExistence(timeout: 5), "Should redirect to Share file")
//
//        app.buttons["Fermer"].tap()
//
//        XCTAssertTrue(tabBar.buttons["Fichiers"].waitForExistence(timeout: 5), "Waiting for folder creation")
//        tabBar.buttons["Fichiers"].tap()
//
//        let newFolder = collectionViewsQuery.cells.containing(.staticText, identifier: testName).element
//        XCTAssertTrue(newFolder.exists, "Created folder should be here")
//
//        newFolder.press(forDuration: 1)
//        collectionViewsQuery.buttons["Supprimer"].tap()
//
//        sleep(1)
//        app.buttons.containing(.staticText, identifier: "Déplacer").element.tap()
//    }

//    func testCreateCommonDocument() {
//        let testName = "UITest CreateCommonDocument"
//
//        let tablesQuery = app.tables
//        let collectionViewsQuery = app.collectionViews
//        let tabBar = app.tabBars
//
//        tabBar.buttons["Ajouter"].tap()
//        tablesQuery.cells.containing(.staticText, identifier: "Dossier").element.tap()
//        tablesQuery.cells.containing(.staticText, identifier: "Dossier commun").element.tap()
//
//        let folderTextField = tablesQuery.textFields["Nom du dossier"]
//        folderTextField.tap()
//        folderTextField.typeText("UITest CreateCommonDocument")
//
//        let someUser = tablesQuery.staticTexts["Certains utilisateurs"]
//        XCTAssertTrue(someUser.exists, "Some user cell should exist")
//        someUser.tap()
//        someUser.tap()
//        tablesQuery.buttons["Créer le dossier"].tap()
//
//        XCTAssertTrue(app.navigationBars["Partage et droits du dossier \(testName)"].waitForExistence(timeout: 5), "Should redirect to Share file")
//        app.buttons["Fermer"].tap()
//
//        XCTAssertTrue(tabBar.buttons["Fichiers"].waitForExistence(timeout: 5), "Waiting for folder creation")
//        tabBar.buttons["Fichiers"].tap()
//
//        let commonDocumentsCell = collectionViewsQuery.cells.containing(.staticText, identifier: "Common documents").element
//        XCTAssertTrue(commonDocumentsCell.exists, "Common documents should exist")
//        commonDocumentsCell.tap()
//
//        let newFolder = collectionViewsQuery.cells.containing(.staticText, identifier: testName).element
//        XCTAssertTrue(newFolder.waitForExistence(timeout: 5), "Created folder should be here")
//
//        newFolder.press(forDuration: 1)
//        collectionViewsQuery.buttons["Supprimer"].tap()
//
//        sleep(1)
//        app.buttons.containing(.staticText, identifier: "Déplacer").element.tap()
//    }
}
