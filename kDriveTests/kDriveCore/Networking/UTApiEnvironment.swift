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
// swiftlint:disable:this identical_operands

@testable import InfomaniakCore
@testable import kDriveCore
import Testing

@Suite("ApiEnvironment Tests")
struct UTApiEnvironment {
    @Test("Production environment properties")
    func productionEnvironment() {
        let prodEnv = ApiEnvironment.prod

        #expect(prodEnv.driveHost == "kdrive.infomaniak.com")
        #expect(prodEnv.apiDriveHost == "api.kdrive.infomaniak.com")
        #expect(prodEnv.onlyOfficeDocumentServerHost == "documentserver.kdrive.infomaniak.com")
        #expect(prodEnv.mqttHost == "info-mq.infomaniak.com")
        #expect(prodEnv.mqttPass == "8QC5EwBqpZ2Z")
    }

    @Test("Preproduction environment properties")
    func preproductionEnvironment() {
        let preprodEnv = ApiEnvironment.preprod

        #expect(preprodEnv.driveHost == "kdrive.preprod.dev.infomaniak.ch")
        #expect(preprodEnv.apiDriveHost == "api.kdrive.preprod.dev.infomaniak.ch")
        #expect(preprodEnv.onlyOfficeDocumentServerHost == "documentserver.kdrive.preprod.dev.infomaniak.ch")
        #expect(preprodEnv.mqttHost == "preprod-info-mq.infomaniak.com")
        #expect(preprodEnv.mqttPass == "4fBt5AdC2P")
    }

    @Test("Custom host with orphan")
    func customHostWithOrphan() {
        let customHost = ApiEnvironment.customHost("orphan.example.com")

        #expect(customHost.driveHost == "orphan.example.com")
        #expect(customHost.apiDriveHost == "orphan.example.com")
        #expect(customHost.onlyOfficeDocumentServerHost == "documentserver.kdrive.preprod.dev.infomaniak.ch")
        #expect(customHost.mqttHost == "preprod-info-mq.infomaniak.com")
        #expect(customHost.mqttPass == "4fBt5AdC2P")
    }

    @Test("Custom host without orphan")
    func customHostWithoutOrphan() {
        let customHost = ApiEnvironment.customHost("custom.example.com")

        #expect(customHost.driveHost == "kdrive.custom.example.com")
        #expect(customHost.apiDriveHost == "api.kdrive.custom.example.com")
        #expect(customHost.onlyOfficeDocumentServerHost == "documentserver.kdrive.custom.example.com")
        #expect(customHost.mqttHost == "preprod-info-mq.infomaniak.com")
        #expect(customHost.mqttPass == "4fBt5AdC2P")
    }

    @Test("Equatable conformance")
    func equatableConformance() {
        #expect(ApiEnvironment.prod == ApiEnvironment.prod)
        #expect(ApiEnvironment.preprod == ApiEnvironment.preprod)
        #expect(ApiEnvironment.customHost("test.com") == ApiEnvironment.customHost("test.com"))
        #expect(ApiEnvironment.prod != ApiEnvironment.preprod)
    }
}
