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

///Helper class contains methods for tracking user's interaction with `Messages`
class MessageInteractionTracker {

    private static let LOG_TAG = "MessageInteractionTracker"

    ///Processes `Generic Data` event to send message tracking request to the configured Campaign server. If the current Configuration properties do not allow sending track request, no request is sent.
    /// - Parameters:
    ///    - event: `Event`to be processed
    ///    - state: Current `Campaign State`
    ///    - campaign: Instance of `Campaign` type
    static func processMessageInformation(event: Event, state: CampaignState, eventDispatcher: Campaign.EventDispatcher) {
        guard state.canSendTrackInfoWithCurrentState() else {
            Log.debug(label: LOG_TAG, "\(#function) - Campaign extension is not configured to send message track request.")
            return
        }

        guard let eventData = event.data else {
            Log.debug(label: LOG_TAG, "\(#function) - Cannot send message track request, eventData is null.")
            return
        }

        guard let broadlogId = eventData[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID] as? String, !broadlogId.isEmpty else {
            Log.debug(label: LOG_TAG, "\(#function) - Cannot send message track request, broadlogId is empty.")
            return
        }

        guard let deliveryId = eventData[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID] as? String, !deliveryId.isEmpty else {
            Log.debug(label: LOG_TAG, "\(#function) - Cannot send message track request, deliveryId is empty.")
            return
        }

        guard let action = eventData[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION] as? String, !action.isEmpty else {
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

    ///Dispatches an event with action `click` and message `deliveryId`. This is to mark that a notification is interacted by user.    
    private static func dispatchMessageEvent(action: String, deliveryId: String, eventDispatcher: Campaign.EventDispatcher) {

        guard action == "2" || action == "1" else { //Dispatch only when action is open(2) or click(1)
            Log.trace(label: LOG_TAG, "\(#function) - Action received is other than viewed or clicked, so cannot dispatch Message Event.")
            return
        }

        guard let decimalDeliveryId = Int(deliveryId, radix: 16) else {
            Log.trace(label: LOG_TAG, "\(#function) - Unable to convert hex deliveryId value to decimal format, so cannot dispatch Message Event.")
            return
        }
        let actionKey: String
        if action == "1" {
            actionKey = CampaignConstants.EventDataKeys.MESSAGE_VIEWED
        } else {
            actionKey = CampaignConstants.EventDataKeys.MESSAGE_CLICKED
        }

        let contextData = [
            CampaignConstants.EventDataKeys.MESSAGE_ID: "\(decimalDeliveryId)",
            actionKey: "1"
        ]
        eventDispatcher("DataForMessageRequest", EventType.campaign, EventSource.responseContent, contextData)
    }
}
