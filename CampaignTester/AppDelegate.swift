/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import UIKit
import UserNotifications
import AEPCore
import AEPIdentity
import AEPCampaign
import AEPLifecycle
import AEPUserProfile
import AEPSignal
import AEPServices
import AEPAssurance

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let LAUNCH_ENVIRONMENT_FILE_ID = "31d8b0ad1f9f/3a905906efff/launch-cb3acd193018-development"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Identity.self, Campaign.self, Lifecycle.self, UserProfile.self, Signal.self, AEPAssurance.self]) {
            // Use the App id assigned to this application via Adobe Launch
            MobileCore.configureWith(appId: self.LAUNCH_ENVIRONMENT_FILE_ID)
            AEPAssurance.startSession(URL(string: "default://swift-acs?adb_validation_sessionid=b98cafbb-f390-420a-9e78-09c37669df34")!)
        }

        // request permission to display notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print("error encountered when requesting notification authorization: \(error)")
                // Handle the error here.
            }
            // Enable or disable features based on the authorization.
        }

        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    /// Handle local notifications if they arrive while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.sound, .alert])
    }

    /// Handle local notification clickthrough to send local notification tracking and/or open any included deeplink
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // send local notification clickthrough tracking
        guard var userInfo = response.notification.request.content.userInfo as? [String: Any] else { return }
        userInfo["action"] = "2"
        MobileCore.collectMessageInfo(userInfo)
        // open any included adb deeplink
        guard let deeplink = userInfo["adb_deeplink"] as? String, let url = URL(string: deeplink) else { return }
        ServiceProvider.shared.urlService.openUrl(url)
    }

}
