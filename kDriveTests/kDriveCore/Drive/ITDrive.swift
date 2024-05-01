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

import kDriveCore
import XCTest

/// Integration tests for Drive
final class ITDrive: XCTestCase {
    // MARK: - Parsing

    private func freeDriveJson() -> Data? {
        JSONHelper.data(forResource: "free_drive", withExtension: "json")
    }

    private func paidDriveJson() -> Data? {
        JSONHelper.data(forResource: "paid_drive", withExtension: "json")
    }

    func testFreeDriveIsFree() {
        // GIVEN
        guard let driveData = freeDriveJson() else {
            XCTFail("Unexpected")
            return
        }

        let decoder = JSONDecoder()

        // WHEN
        do {
            let drive = try decoder.decode(Drive.self, from: driveData)

            // THEN
            XCTAssertTrue(drive.isFreePack, "We expect this drive to be free pack")
            XCTAssertEqual(drive.pack.drivePackId, DrivePackId.free, "We expect this drive to be a free pack")
        } catch {
            XCTFail("Unexpected Error \(error)")
        }
    }

    func testPaidDriveIsPaid() {
        // GIVEN
        guard let driveData = paidDriveJson() else {
            XCTFail("Unexpected")
            return
        }

        let decoder = JSONDecoder()

        // WHEN
        do {
            let drive = try decoder.decode(Drive.self, from: driveData)

            // THEN
            XCTAssertFalse(drive.isFreePack, "We expect this drive to be a paid pack")
            XCTAssertEqual(drive.pack.drivePackId, DrivePackId.team, "We expect this drive to be a team pack")
        } catch {
            XCTFail("Unexpected Error \(error)")
        }
    }
}
