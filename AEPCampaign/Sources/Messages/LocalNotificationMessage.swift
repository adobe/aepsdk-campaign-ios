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
    private let LOG_TAG = "LocalNotificationMessage"

    private var consequence: CampaignRuleConsequence
    internal static var eventDispatcher: Campaign.EventDispatcher?
    internal static var state: CampaignState?
    internal var messageId: String

    private var content: String
    private var deeplink: String
    private var sound: String
    private var userData: [String: Any]
    private var fireDate: TimeInterval
    private var title: String

    /// LocalNotification class initializer
    ///  - Parameters:
    ///    - consequence: CampaignRuleConsequence containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    required init(consequence: CampaignRuleConsequence, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) {
        self.consequence = consequence
        self.messageId = consequence.id
        Self.eventDispatcher = eventDispatcher
        Self.state = state
        self.content = ""
        self.deeplink = ""
        self.sound = ""
        self.userData = [:]
        self.fireDate = TimeInterval(0)
        self.title = ""
        self.parseLocalNotificationMessagePayload()
    }

    func triggered(deliveryId: String) {
        guard let eventDispatcher = Self.eventDispatcher else {
            Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot dispatch message triggered event, the event dispatcher is nil.")
            return
        }
        Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Dispatching message triggered event.")
        MessageInteractionTracker.dispatchMessageEvent(action: CampaignConstants.ContextDataKeys.MESSAGE_TRIGGERED, deliveryId: deliveryId, eventDispatcher: eventDispatcher)
    }

    func viewed(deliveryId: String) {
        guard let eventDispatcher = Self.eventDispatcher else {
            Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot dispatch message triggered event, the event dispatcher is nil.")
            return
        }
        Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Dispatching message triggered event.")
        MessageInteractionTracker.dispatchMessageEvent(action: CampaignConstants.ContextDataKeys.MESSAGE_TRIGGERED, deliveryId: deliveryId, eventDispatcher: eventDispatcher)
    }

    func showMessage() {
        guard !userData.isEmpty else {
            Log.trace(label: LOG_TAG, "\(#function) - Cannot dispatch message info event, user info is nil or empty.")
            return
        }

        guard let broadlogId = userData[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID] as? String, !broadlogId.isEmpty else {
            Log.trace(label: LOG_TAG, "\(#function) - Cannot dispatch message info event, broadlog id is nil or empty.")
            return
        }

        guard let deliveryId = userData[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID] as? String, !deliveryId.isEmpty else {
            Log.trace(label: LOG_TAG, "\(#function) - Cannot dispatch message info event, delivery id is nil or empty.")
            return
        }

        // dispatch triggered event
        triggered(deliveryId: deliveryId)

        // dispatch generic data message info event
        if let eventDispatcher = Self.eventDispatcher, let state = Self.state {
            Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Dispatching generic data triggered event.")
            MessageInteractionTracker.dispatchMessageInfoEvent(broadlogId: broadlogId, deliveryId: deliveryId, action: CampaignConstants.EventDataKeys.MESSAGE_TRIGGERED_ACTION_VALUE, state: state, eventDispatcher: eventDispatcher)
        }

        // schedule local notification
        let content = UNMutableNotificationContent()
        let notificationCenter = UNUserNotificationCenter.current()

        content.body = self.content
        if !title.isEmpty {
            content.title = title
        }
        if !userData.isEmpty {
            content.userInfo = userData
        }
        var trigger: UNTimeIntervalNotificationTrigger?
        if fireDate > TimeInterval(0) {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate, repeats: false)
        }

        let request = UNNotificationRequest(identifier: consequence.id, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error \(error.localizedDescription)")
            }
        }
    }

    func shouldDownloadAssets() -> Bool {
        false
    }

    /// Parses a `CampaignRuleConsequence` instance defining message payload for a `LocalNotificationMessage` object.
    /// Required fields:
    ///     * content: A `String` containing the message content for this message
    /// Optional fields:
    ///     * date: A `TimeInterval` containing number of seconds since epoch to schedule the notification to be shown. This field has priority over that in the "wait" field.
    ///     * wait: A `TimeInterval`containing delay, in seconds, until the notification should show.  If a "date" is specified, this field is ignored.
    ///     * adb_deeplink: A `String` containing a deeplink URL.
    ///     * userData: A `[String: Any]` dictionary containing additional user data.
    ///     * sound: A `String` containing the name of a bundled sound file to use when the notification is triggered.
    ///     * title: A `String` containing the title for this message.
    private func parseLocalNotificationMessagePayload() {
        guard let detailDictionary = consequence.detailDictionary, !detailDictionary.isEmpty else {
            Log.error(label: LOG_TAG, "\(#function) - The consequence details are nil or empty, dropping the local notification.")
            return
        }
        // content is required
        guard let content = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL] as? String, !content.isEmpty else {
            Log.error(label: LOG_TAG, "\(#function) - The content for a local notification is required, dropping the notification.")
            return
        }
        self.content = content

        // prefer the date specified by fire date, otherwise use provided delay. both are optional.
        let fireDate = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_DATE] as? TimeInterval ?? TimeInterval(0)
        if fireDate <= TimeInterval(0) {
            self.fireDate = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_WAIT] as? TimeInterval ?? TimeInterval(0)
        } else {
            self.fireDate = fireDate
        }

        // deeplink is optional
        if let deeplink = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_DEEPLINK] as? String, !deeplink.isEmpty {
            self.deeplink = deeplink
        } else {
            Log.trace(label: LOG_TAG, "\(#function) - Tried to read adb_deeplink for local notification but found none. This is not a required field.")
        }

        // user info is optional
        if let userData = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_USER_INFO] as? [String: Any], !userData.isEmpty {
            self.userData = userData
        } else {
            Log.trace(label: LOG_TAG, "\(#function) - Tried to read userData for local notification but found none. This is not a required field.")
        }

        // sound is optional
        if let sound = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_SOUND] as? String, !sound.isEmpty {
            self.sound = sound
        } else {
            Log.trace(label: LOG_TAG, "\(#function) - Tried to read sound for local notification but found none. This is not a required field.")
        }

        // title is optional
        if let title = detailDictionary[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_TITLE] as? String, !title.isEmpty {
            self.title = title
        } else {
            Log.trace(label: LOG_TAG, "\(#function) - Tried to read title for local notification but found none. This is not a required field.")
        }
    }
}
