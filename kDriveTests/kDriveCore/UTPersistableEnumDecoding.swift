/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

final class UTPersistableEnumDecoding: XCTestCase {
    struct ObjectWithPersistableEnum: Codable {
        let maintenanceReason: MaintenanceReason
    }

    func testDecodingSnakeCase() throws {
        // GIVEN
        let jsonToDecode = Data("""
        {
        "maintenance_reason": "invoice_overdue"
        }
        """.utf8)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // WHEN
        let decodedObject = try? decoder.decode(ObjectWithPersistableEnum.self, from: jsonToDecode)

        // THEN
        XCTAssertNotNil(decodedObject, "Decoding shouldn't fail")
        XCTAssertEqual(decodedObject?.maintenanceReason, MaintenanceReason.invoiceOverdue)
    }
}
