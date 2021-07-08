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

protocol StoreObserverDelegate: AnyObject {
    func storeObserverRestoreDidSucceed()
    func storeObserverDidReceiveMessage(_ message: String)
}

class StoreObserver: NSObject {
    static let shared = StoreObserver()

    /// Indicates whether the user is allowed to make payments.
    var isAuthorizedForPayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }

    /// Keeps track of all purchases.
    var purchased = [SKPaymentTransaction]()

    /// Keeps track of all restored purchases.
    var restored = [SKPaymentTransaction]()

    /// Indicates whether there are restorable purchases.
    fileprivate var hasRestorablePurchases = false

    weak var delegate: StoreObserverDelegate?

    // MARK: - Public methods

    /// Create and add a payment request to the payment queue.
    func buy(_ product: SKProduct) {
        let payment = SKMutablePayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    /// Restores all previously completed purchases.
    func restore() {
        if !restored.isEmpty {
            restored.removeAll()
        }
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    // MARK: - Private methods

    override private init() {}

    private func handlePurchased(_ transaction: SKPaymentTransaction) {
        purchased.append(transaction)
        print("Deliver content for \(transaction.payment.productIdentifier)")

        // Finish the successful transaction
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func handleFailed(_ transaction: SKPaymentTransaction) {
        var message = "Purchase of \(transaction.payment.productIdentifier) failed"

        if let error = transaction.error {
            message += "\nError: \(error.localizedDescription)"
            print("Error: \(error.localizedDescription)")
        }

        // Do not send any notifications when the user cancels the purchase
        if (transaction.error as? SKError)?.code != .paymentCancelled {
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage(message)
            }
        }
        // Finish the failed transaction
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func handleRestored(_ transaction: SKPaymentTransaction) {
        hasRestorablePurchases = true
        restored.append(transaction)
        print("Restore content for \(transaction.payment.productIdentifier)")

        DispatchQueue.main.async {
            self.delegate?.storeObserverRestoreDidSucceed()
        }
        // Finishes the restored transaction
        SKPaymentQueue.default().finishTransaction(transaction)
    }
}

// MARK: - Store Kit payment transaction observer

extension StoreObserver: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // Called when there are transactions in the payment queue
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                break
            case .deferred:
                break
            case .purchased:
                handlePurchased(transaction)
            case .failed:
                handleFailed(transaction)
            case .restored:
                handleRestored(transaction)
            @unknown default:
                fatalError("Unknown payment transaction case.")
            }
        }
    }

    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        // Logs all transactions that have been removed from the payment queue
        for transaction in transactions {
            print("\(transaction.payment.productIdentifier) was removed from the payment queue.")
        }
    }

    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        // Called when an error occur while restoring purchases
        if let error = error as? SKError, error.code != .paymentCancelled {
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage(error.localizedDescription)
            }
        }
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        // Called when all restorable transactions have been processed by the payment queue
        print("All restorable transactions have been processed by the payment queue.")

        if !hasRestorablePurchases {
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage("There are no restorable purchases.\nOnly previously bought non-consumable products and auto-renewable subscriptions can be restored.")
            }
        }
    }
}
