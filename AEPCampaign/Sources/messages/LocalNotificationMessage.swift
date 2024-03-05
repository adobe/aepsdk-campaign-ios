/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License")
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AEPCore
import AEPServices
import Foundation
import UIKit

struct LocalNotificationMessage: CampaignMessaging {
    private static let LOG_TAG = "LocalNotificationMessage"

    var eventDispatcher: Campaign.EventDispatcher?
    var messageId: String?

    private var state: CampaignState?
    private var content: String?
    private var deeplink: String?
    private var sound: String?
    private var category: String?
    private var userData: [String: Any]?
    private var fireDate: TimeInterval?
    private var title: String?

    /// LocalNotification struct initializer. It is accessed via the `createMessageObject` method.
    ///  - Parameters:
    ///    - consequence: `RuleConsequence` containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    private init(consequence: RuleConsequence, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) {
        self.messageId = consequence.id
        self.eventDispatcher = eventDispatcher
        self.state = state
        self.parseLocalNotificationMessagePayload(consequence: consequence)
    }

    /// Creates a `LocalNotificationMessage` object
    ///  - Parameters:
    ///    - consequence: `RuleConsequence` containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    ///  - Returns: A Message object or nil if the message object creation failed.
    static func createMessageObject(consequence: RuleConsequence, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) -> CampaignMessaging? {
        let localNotificationMessage = LocalNotificationMessage(consequence: consequence, state: state, eventDispatcher: eventDispatcher)
        // content is required so no message object is returned if it is nil
        guard localNotificationMessage.content != nil else {
            return nil
        }
        return localNotificationMessage
    }

    /// Validates the parsed Local Notification message payload and if valid, attempts to send message tracking events.
    /// It then calls `scheduleLocalNotification` to schedule a local notification with the `UNUserNotificationCenter`.
    func showMessage() {
        // dispatch triggered event
        triggered()
        // schedule local notification
        scheduleLocalNotification()
        // dispatch generic data message info event
        guard let userData = userData, !userData.isEmpty else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot dispatch message info event, user data is nil or empty.")
            return
        }
        guard let deliveryId =
            userData[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID] as? String,
            let broadlogId = userData[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID] as? String,
            !deliveryId.isEmpty,
            !broadlogId.isEmpty else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot dispatch message info event, delivery id or broadlog id is nil or empty.")
            return
        }
        guard let eventDispatcher = self.eventDispatcher else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot dispatch message info event, the event dispatcher is nil.")
            return
        }
        guard let state = self.state else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot dispatch message info event, the Campaign State is nil.")
            return
        }
        Log.trace(label: Self.LOG_TAG, "\(#function) - Dispatching generic data triggered event.")
        MessageInteractionTracker.dispatchMessageInfoEvent(broadlogId: broadlogId, deliveryId: deliveryId, action: CampaignConstants.EventDataKeys.MESSAGE_TRIGGERED_ACTION_VALUE, state: state, eventDispatcher: eventDispatcher)
    }

    /// Schedule the local notification with the `UNUserNotificationCenter`.
    private func scheduleLocalNotification() {
        // content (message body) is required, bail early if we don't have it
        guard let localNotificationBody = self.content else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot schedule local notification, the message body is nil.")
            return
        }

        let unMutableNotificationContent = UNMutableNotificationContent()
        let notificationCenter = UNUserNotificationCenter.current()

        unMutableNotificationContent.body = localNotificationBody

        // title, sound, category, deeplink, user info, and fire date are optional
        if let title = title, !title.isEmpty {
            unMutableNotificationContent.title = title
        }
        if let sound = sound, !sound.isEmpty {
            unMutableNotificationContent.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        } else {
            unMutableNotificationContent.sound = UNNotificationSound.default
        }
        if let category = category, !category.isEmpty {
            unMutableNotificationContent.categoryIdentifier = category
        }
        var userInfo: [String: Any] = [:]
        if let deeplink = deeplink, !deeplink.isEmpty {
            userInfo[CampaignConstants.EventDataKeys.RulesEngine.Detail.DEEPLINK] = deeplink
        }
        if let userData = userData, !userData.isEmpty {
            userInfo.merge(userData) { _, new in new }
        }
        unMutableNotificationContent.userInfo = userInfo
        var trigger: UNTimeIntervalNotificationTrigger?
        if let fireDate = fireDate, fireDate > TimeInterval(0) {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate, repeats: false)
        }
        let messageId = self.messageId ?? ""
        let request = UNNotificationRequest(identifier: messageId, content: unMutableNotificationContent, trigger: trigger)

        Log.trace(label: Self.LOG_TAG, "\(#function) - Scheduling local notification for message id \(messageId).")
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error \(error.localizedDescription)")
            }
        }
    }

    /// Parses a `CampaignRuleConsequence` instance defining message payload for a `LocalNotificationMessage` object.
    /// Required fields:
    ///     * content: A `String` containing the message content for this message
    /// Optional fields:
    ///     * date: A `TimeInterval` containing number of seconds since epoch to schedule the notification to be shown.
    ///     This field has priority over that in the "wait" field.
    ///     * wait: A `TimeInterval`containing delay, in seconds, until the notification should show.  If a "date" is specified, this field is ignored.
    ///     * adb_deeplink: A `String` containing a deeplink URL.
    ///     * userData: A `[String: Any]` dictionary containing additional user data.
    ///     * sound: A `String` containing the name of a bundled sound file to use when the notification is triggered.
    ///     * category: A `String` containing an app defined category for the notification.
    ///     * title: A `String` containing the title for this message.
    ///  - Parameter consequence: `RuleConsequence` containing a Message-defining payload
    private mutating func parseLocalNotificationMessagePayload(consequence: RuleConsequence) {
        guard !consequence.details.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The consequence details are nil or empty, dropping the local notification.")
            return
        }

        // content is required
        guard let content = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.CONTENT] as? String, !content.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The content for a local notification is required, dropping the notification.")
            return
        }
        self.content = content

        // prefer the date specified by fire date, otherwise use provided delay. both are optional.
        let fireDate = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.DATE] as? TimeInterval ?? TimeInterval(0)
        if fireDate <= TimeInterval(0) {
            // default to showing the local notification immediately
            let wait = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.WAIT] as? Int ?? 0
            self.fireDate = TimeInterval(wait)
        } else {
            self.fireDate = fireDate
        }

        // deeplink is optional
        if let deeplink = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.DEEPLINK] as? String, !deeplink.isEmpty {
            self.deeplink = deeplink
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read adb_deeplink for local notification but found none. This is not a required field.")
        }

        // user info is optional
        if let userData = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.USER_INFO] as? [String: Any], !userData.isEmpty {
            self.userData = userData
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read userData for local notification but found none. This is not a required field.")
        }

        // sound is optional
        if let sound = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.SOUND] as? String, !sound.isEmpty {
            self.sound = sound
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read sound for local notification but found none. This is not a required field.")
        }

        // category is optional
        if let category = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.CATEGORY] as? String, !category.isEmpty {
            self.category = category
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read category for local notification but found none. This is not a required field.")
        }

        // title is optional
        if let title = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.TITLE] as? String, !title.isEmpty {
            self.title = title
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read title for local notification but found none. This is not a required field.")
        }
    }

    // no-op for local notifications
    ///  - Returns: `false` as assets are not downloaded for local notifications.
    func shouldDownloadAssets() -> Bool {
        return false
    }
}
