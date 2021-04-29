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

import Foundation
import AEPCore
import AEPServices

class LocalNotificationMessage: Message {
    private static let LOG_TAG = "LocalNotificationMessage"

    internal static var eventDispatcher: Campaign.EventDispatcher?
    internal var messageId: String?

    private var state: CampaignState?
    private var content: String?
    private var deeplink: String?
    private var sound: String?
    private var category: String?
    private var userData: [String: Any]?
    private var fireDate: TimeInterval?
    private var title: String?

    /// LocalNotification class initializer. It is accessed via the `createMessageObject` method.
    ///  - Parameters:
    ///    - consequence: CampaignRuleConsequence containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    private init(consequence: CampaignRuleConsequence, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) {
        self.messageId = consequence.id
        Self.eventDispatcher = eventDispatcher
        self.state = state
        self.parseLocalNotificationMessagePayload(consequence: consequence)
    }

    /// Creates a Local Notification Message object
    ///  - Parameters:
    ///    - consequence: CampaignRuleConsequence containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    ///  - Returns: A Message object or nil if the message object creation failed.
    @discardableResult static func createMessageObject(consequence: CampaignRuleConsequence?, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) -> Message? {
        guard let consequence = consequence else {
            Log.trace(label: LOG_TAG, "\(#function) - Cannot create a Local Notification Message object, the consequence is nil.")
            return nil
        }
        let messageObject = LocalNotificationMessage(consequence: consequence, state: state, eventDispatcher: eventDispatcher)
        return messageObject
    }

    /// Generates a dictionary with message data for a "message triggered" event and dispatches it using the Campaign event dispatcher.
    /// - Parameter deliveryId: the delivery id of the triggered message
    func triggered(deliveryId: String) {
        guard let eventDispatcher = Self.eventDispatcher else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot dispatch message triggered event, the event dispatcher is nil.")
            return
        }
        Log.trace(label: Self.LOG_TAG, "\(#function) - Dispatching message triggered event.")
        MessageInteractionTracker.dispatchMessageEvent(action: CampaignConstants.ContextDataKeys.MESSAGE_TRIGGERED, deliveryId: deliveryId, eventDispatcher: eventDispatcher)
    }

    /// Validates the parsed Local Notification message payload and if valid, creates a `UNNotificationRequest` and schedules it with
    /// the `UNUserNotificationCenter`.
    func showMessage() {
        if let userData = userData, !userData.isEmpty {
            guard let broadlogId = userData[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID] as? String, !broadlogId.isEmpty else {
                Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot dispatch message info event, broadlog id is nil or empty.")
                return
            }

            guard let deliveryId = userData[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID] as? String, !deliveryId.isEmpty else {
                Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot dispatch message info event, delivery id is nil or empty.")
                return
            }

            // dispatch triggered event
            triggered(deliveryId: deliveryId)

            // dispatch generic data message info event
            if let eventDispatcher = Self.eventDispatcher, let state = state {
                Log.trace(label: Self.LOG_TAG, "\(#function) - Dispatching generic data triggered event.")
                MessageInteractionTracker.dispatchMessageInfoEvent(broadlogId: broadlogId, deliveryId: deliveryId, action: CampaignConstants.EventDataKeys.MESSAGE_TRIGGERED_ACTION_VALUE, state: state, eventDispatcher: eventDispatcher)
            }
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot dispatch message info event, user info is nil or empty.")
        }
        // schedule local notification
        scheduleLocalNotification()
    }

    private func scheduleLocalNotification() {
        // content (message body) is required, bail early if we don't have it
        guard let body = self.content else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot show local notification, the message detail is nil.")
            return
        }

        let content = UNMutableNotificationContent()
        let notificationCenter = UNUserNotificationCenter.current()

        content.body = body

        // title, sound, category, deeplink, user info, and fire date are optional
        if let title = title, !title.isEmpty {
            content.title = title
        }
        if let sound = sound, !sound.isEmpty {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        } else {
            content.sound = UNNotificationSound.default
        }
        if let category = category, !category.isEmpty {
            content.categoryIdentifier = category
        }
        var userInfo: [String: Any] = [:]
        if let deeplink = deeplink, !deeplink.isEmpty {
            userInfo[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_DEEPLINK] = deeplink
        }
        if let userData = userData, !userData.isEmpty {
            userInfo.merge(userData) { _, new in new }
        }
        content.userInfo = userInfo
        var trigger: UNTimeIntervalNotificationTrigger?
        if let fireDate = fireDate, fireDate > TimeInterval(0) {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate, repeats: false)
        }
        let messageId = self.messageId ?? ""
        let request = UNNotificationRequest(identifier: messageId, content: content, trigger: trigger)

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
    ///  - Parameter consequence: CampaignRuleConsequence containing a Message-defining payload
    private func parseLocalNotificationMessagePayload(consequence: CampaignRuleConsequence) {
        guard let detailDictionary = consequence.detailDictionary, !detailDictionary.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The consequence details are nil or empty, dropping the local notification.")
            return
        }
        // content is required
        guard let content = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL] as? String, !content.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The content for a local notification is required, dropping the notification.")
            return
        }
        self.content = content

        // prefer the date specified by fire date, otherwise use provided delay. both are optional.
        let fireDate = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_DATE] as? TimeInterval ?? TimeInterval(0)
        if fireDate <= TimeInterval(0) {
            self.fireDate = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_WAIT] as? TimeInterval ?? TimeInterval(0.1)
        } else {
            self.fireDate = fireDate
        }

        // deeplink is optional
        if let deeplink = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_DEEPLINK] as? String, !deeplink.isEmpty {
            self.deeplink = deeplink
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read adb_deeplink for local notification but found none. This is not a required field.")
        }

        // user info is optional
        if let userData = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_USER_INFO] as? [String: Any], !userData.isEmpty {
            self.userData = userData
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read userData for local notification but found none. This is not a required field.")
        }

        // sound is optional
        if let sound = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_SOUND] as? String, !sound.isEmpty {
            self.sound = sound
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read sound for local notification but found none. This is not a required field.")
        }

        // category is optional
        if let category = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_CATEGORY] as? String, !category.isEmpty {
            self.category = category
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read category for local notification but found none. This is not a required field.")
        }

        // title is optional
        if let title = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_TITLE] as? String, !title.isEmpty {
            self.title = title
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read title for local notification but found none. This is not a required field.")
        }
    }

    // no-op for local notifications
    internal func shouldDownloadAssets() -> Bool {
        return false
    }
}
