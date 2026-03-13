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
import StoreKit

protocol StoreManagerDelegate: AnyObject {
    func storeManagerDidReceiveResponse(_ response: StoreResponse)
    func storeManagerDidReceiveMessage(_ message: String)
}

class StoreManager: NSObject {
    static let shared = StoreManager()

    var availableProducts = [SKProduct]()
    var invalidProductIdentifiers = [String]()
    var productRequest: SKProductsRequest!
    var storeResponse = StoreResponse()

    weak var delegate: StoreManagerDelegate?

    // MARK: - Public methods

    /// Starts the product request with the specified identifiers.
    func startProductRequest(with identifiers: [String]) {
        fetchProducts(matchingIdentifiers: identifiers)
    }

    // periphery:ignore
    /// Existing product's title matching the specified product identifier.
    func title(matchingIdentifier identifier: String) -> String? {
        guard !availableProducts.isEmpty else { return nil }

        // Search availableProducts for a product whose productIdentifier property matches identifier
        let result = availableProducts.first { $0.productIdentifier == identifier }

        return result?.localizedTitle
    }

    // periphery:ignore
    /// Existing product's title associated with the specified payment transaction.
    func title(matchingPaymentTransaction transaction: SKPaymentTransaction) -> String {
        let title = title(matchingIdentifier: transaction.payment.productIdentifier)
        return title ?? transaction.payment.productIdentifier
    }

    // MARK: - Private methods

    override private init() {
        // META: keep SonarCloud happy
    }

    // periphery:ignore
    /// Fetches information about your products from the App Store.
    private func fetchProducts(matchingIdentifiers identifiers: [String]) {
        // Create a set for the product identifiers
        let productIdentifiers = Set(identifiers)

        // Initialize the product request with the above identifiers
        productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productRequest.delegate = self

        // Send the request to the App Store
        productRequest.start()
    }
}

// MARK: - Store Kit products request delegate

extension StoreManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if !storeResponse.isEmpty {
            storeResponse.removeAll()
        }

        // products contains products whose identifiers have been recognized by the App Store. As such, they can be purchased
        if !response.products.isEmpty {
            availableProducts = response.products
        }

        // invalidProductIdentifiers contains all product identifiers not recognized by the App Store
        if !response.invalidProductIdentifiers.isEmpty {
            invalidProductIdentifiers = response.invalidProductIdentifiers
        }

        if !availableProducts.isEmpty {
            storeResponse.availableProducts = availableProducts
        }

        if !invalidProductIdentifiers.isEmpty {
            storeResponse.invalidProductIdentifiers = invalidProductIdentifiers
        }

        if !storeResponse.isEmpty {
            Task { @MainActor in
                self.delegate?.storeManagerDidReceiveResponse(self.storeResponse)
            }
        }
    }
}

// MARK: - Store Kit request delegate

extension StoreManager: SKRequestDelegate {
    func request(_ request: SKRequest, didFailWithError error: Error) {
        Task { @MainActor in
            self.delegate?.storeManagerDidReceiveMessage(error.localizedDescription)
        }
    }
}
