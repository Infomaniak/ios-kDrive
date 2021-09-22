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

import CocoaLumberjackSwift
import Foundation
import kDriveCore
import StoreKit

protocol StoreObserverDelegate: AnyObject {
    func storeObserverRestoreDidSucceed()
    func storeObserverPurchaseDidSucceed(transaction: SKPaymentTransaction, receiptString: String)
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
    func buy(_ product: SKProduct, userId: Int, driveId: Int) {
        let payment = SKMutablePayment(product: product)
        payment.applicationUsername = "\(userId)_\(driveId)"
        SKPaymentQueue.default().add(payment)
    }

    /// Restores all previously completed purchases.
    func restore() {
        if !restored.isEmpty {
            restored.removeAll()
        }
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    /// Retrieve the receipt data from the app on the device.
    func getReceipt() -> String? {
        // Get the receipt if it's available
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)

                return receiptData.base64EncodedString()
            } catch {
                DDLogError("Couldn't read receipt data with error: \(error.localizedDescription)")
            }
        } else {
            DDLogError("Cannot find App Store receipt")
        }

        return nil
    }

    // MARK: - Private methods

    override private init() {}

    private func handlePurchased(_ transaction: SKPaymentTransaction) {
        purchased.append(transaction)
        DDLogInfo("Deliver content for \(transaction.payment.productIdentifier)")

        if let receiptString = getReceipt() {
            DispatchQueue.main.async {
                self.delegate?.storeObserverPurchaseDidSucceed(transaction: transaction, receiptString: receiptString)
            }
        }
        // Finish the successful transaction
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func handleFailed(_ transaction: SKPaymentTransaction) {
        var message = "Purchase of \(transaction.payment.productIdentifier) failed"

        if let error = transaction.error {
            message += "\nError: \(error.localizedDescription)"
            DDLogError("[StoreObserver] Transaction error: \(error.localizedDescription)")
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
        DDLogInfo("[StoreObserver] Restore content for \(transaction.payment.productIdentifier)")

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
            DDLogInfo("[StoreObserver] \(transaction.payment.productIdentifier) was removed from the payment queue.")
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
        DDLogInfo("[StoreObserver] All restorable transactions have been processed by the payment queue.")

        if !hasRestorablePurchases {
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage("There are no restorable purchases.\nOnly previously bought non-consumable products and auto-renewable subscriptions can be restored.")
            }
        }
    }
}
