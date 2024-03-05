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

/// Helper enum containing methods for tracking user interactions with `Messages`
enum MessageInteractionTracker {

    private static let LOG_TAG = "MessageInteractionTracker"

    /// Processes `Generic Data` events to send message tracking requests to the configured Campaign server. If the current Configuration properties do not allow sending track requests, no request is sent.
    /// - Parameters:
    ///    - event: `Event`to be processed
    ///    - state: Current `Campaign State`
    ///    - eventDispatcher: The Campaign event dispatcher
    static func processMessageInformation(event: Event, state: CampaignState, eventDispatcher: Campaign.EventDispatcher) {
        guard state.canSendTrackInfoWithCurrentState() else {
            Log.debug(label: LOG_TAG, "\(#function) - Campaign extension is not configured to send message track request.")
            return
        }

        guard let broadlogId = event.broadlogId, !broadlogId.isEmpty else {
            Log.debug(label: LOG_TAG, "\(#function) - Cannot send message track request, broadlogId is empty.")
            return
        }

        guard let deliveryId = event.deliveryId, !deliveryId.isEmpty else {
            Log.debug(label: LOG_TAG, "\(#function) - Cannot send message track request, deliveryId is empty.")
            return
        }

        guard let action = event.action, !action.isEmpty else {
            Log.debug(label: LOG_TAG, "\(#function) - Cannot send message track request, action is empty.")
            return
        }

        dispatchMessageEvent(action: action, deliveryId: deliveryId, eventDispatcher: eventDispatcher)

        guard let url = URL.buildTrackingUrl(host: state.campaignServer ?? "", broadLogId: broadlogId, deliveryId: deliveryId, action: action, ecid: state.ecid ?? "") else {
            Log.warning(label: LOG_TAG, "\(#function) - Unable to track Message. Error in creating tracking url.")
            return
        }
        state.processRequest(url: url, payload: "", event: event)
    }

    /// Creates a generic data event to send an internal message track request to the configured Campaign server.
    /// If the current Configuration properties do not allow sending track requests, no request is sent.
    /// - Parameters:
    ///    - broadlogId: The tracked message's broadlog id
    ///    - deliveryId: The tracked message's delivery id
    ///    - action: The tracked message's interaction type
    ///    - state: Current `Campaign State`
    ///    - eventDispatcher: The Campaign event dispatcher
    static func dispatchMessageInfoEvent(broadlogId: String, deliveryId: String, action: String, state: CampaignState, eventDispatcher: Campaign.EventDispatcher) {
        guard state.canSendTrackInfoWithCurrentState() else {
            Log.debug(label: LOG_TAG, "\(#function) - Campaign extension is not configured to send message track request.")
            return
        }
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadlogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        eventDispatcher("InternalGenericDataEvent", EventType.genericData, EventSource.os, eventData)
    }

    /// Dispatches an event with action `viewed` or `clicked` and message `deliveryId`. This is to mark that a notification was interacted by a user.
    /// - Parameters:
    ///    - action: The tracked message's interaction type
    ///    - deliveryId: The tracked message's delivery id
    ///    - eventDispatcher: The Campaign event dispatcher
    private static func dispatchMessageEvent(action: String, deliveryId: String, eventDispatcher: Campaign.EventDispatcher) {

        guard action == CampaignConstants.EventDataKeys.MESSAGE_CLICKED_ACTION_VALUE
            || action == CampaignConstants.EventDataKeys.MESSAGE_VIEWED_ACTION_VALUE else { // Dispatch only when action is clicked(2) or viewed(1)
            Log.trace(label: LOG_TAG, "\(#function) - Action received is other than viewed or clicked, so cannot dispatch Message Event.")
            return
        }

        guard let decimalDeliveryId = Int(deliveryId, radix: 16) else {
            Log.trace(label: LOG_TAG, "\(#function) - Unable to convert hex deliveryId value to decimal format, so cannot dispatch Message Event.")
            return
        }
        let actionKey: String
        if action == CampaignConstants.EventDataKeys.MESSAGE_VIEWED_ACTION_VALUE {
            actionKey = CampaignConstants.ContextDataKeys.MESSAGE_VIEWED
        } else {
            actionKey = CampaignConstants.ContextDataKeys.MESSAGE_CLICKED
        }

        let contextData = [
            CampaignConstants.ContextDataKeys.MESSAGE_ID: "\(decimalDeliveryId)",
            actionKey: CampaignConstants.ContextDataKeys.MESSAGE_ACTION_EXISTS_VALUE
        ]
        dispatchMessageInteraction(data: contextData, eventDispatcher: eventDispatcher)
    }

    /// Invokes the Campaign event dispatcher to dispatch message interaction events
    static func dispatchMessageInteraction(data: [String: Any], eventDispatcher: Campaign.EventDispatcher) {
        eventDispatcher("DataForMessageRequest", EventType.campaign, EventSource.responseContent, data)
    }
}
