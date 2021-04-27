//
//  Logging.swift
//  kDriveCore
//
//  Created by Philippe Weidmann on 19.04.21.
//

import Foundation
import CocoaLumberjack
import Atlantis
import Sentry
import MetricKit

@available(iOS 14.0, *)
class AppMetrics: NSObject, MXMetricManagerSubscriber {

    static let shared = AppMetrics()
    private let shared = MXMetricManager.shared

    func receiveReports() {
        let shared = MXMetricManager.shared
        shared.add(self)
        processMetrics(payloads: shared.pastPayloads)
    }

    private func processMetrics(payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let exitMetrics = payload.applicationExitMetrics {
                SentrySDK.capture(message: "Exit metrics") { (scope) in
                    let attachement = Attachment(data: exitMetrics.jsonRepresentation(), filename: "Exit-metrics.json")
                    scope.add(attachement)
                }
            }
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        processMetrics(payloads: payloads)
    }

}


public class Logging {

    public static func initLogging() {
        initLogger()
        initNetworkLogging()
        initSentry()
        initMetrics()
    }

    private static func initLogger() {
        DDLog.add(DDOSLogger.sharedInstance)
        let fileLogger: DDFileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)
    }

    private static func initMetrics() {
        if #available(iOS 14.0, *) {
            AppMetrics.shared.receiveReports()
        }
    }

    private static func initNetworkLogging() {
        #if DEBUG
            if !Constants.isInExtension {
                Atlantis.start(hostName: ProcessInfo.processInfo.environment["hostname"])
            }
        #endif
    }

    private static func initSentry() {
        SentrySDK.start { options in
            options.dsn = "https://fb65d0bcbf4c4ce795a6e1c1a964da28@sentry.infomaniak.com/4"
            options.beforeSend = { event in
                // if the application is in debug mode discard the events
                #if DEBUG
                    return nil
                #else
                    return event
                #endif
            }
        }
    }
}
