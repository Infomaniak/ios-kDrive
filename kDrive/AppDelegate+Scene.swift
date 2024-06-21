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
import UIKit

extension AppDelegate {
    /** iOS 13 or later
         UIKit uses this delegate when it is about to create and vend a new UIScene instance to the application.
         Use this function to select a configuration to create the new scene with.
         You can define the scene configuration in code here, or define it in the Info.plist.

         The application delegate may modify the provided UISceneConfiguration within this function.
         If the UISceneConfiguration instance that returns from this function does not have a systemType
         that matches the connectingSession's, UIKit asserts.
     */
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        Log.appDelegate("application configurationForConnecting:\(connectingSceneSession)")
        return connectingSceneSession.configuration
    }

    /** iOS 13 or later
         The system calls this delegate when it removes one or more representations from the -[UIApplication openSessions] set
         due to a user interaction or a request from the app itself. If the system discards sessions while the app isn't running,
         it calls this function shortly after the app’s next launch.

         Use this function to:
         Release any resources that were specific to the discarded scenes, as they will NOT return.
         Remove any state or data associated with this session, as it will not return (such as, unsaved draft of a document).
     */
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        Log.appDelegate("application didDiscardSceneSessions:\(sceneSessions)")
    }
}
