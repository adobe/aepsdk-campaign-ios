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

class MessageInteractionTracker {
    
    private let LOG_TAG = "MessageInteractionTracker"
    
    func processMessageInformation(event: Event, state: CampaignState, campaign: Campaign) {
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
        
        dispatchMessageEvent(action: action, deliveryId: deliveryId, campaign: campaign)
        
        guard let url = buildTrackingUrl(host: state.campaignServer ?? "", broadLogId: broadlogId, deliveryId: deliveryId, action: action, ecid: state.ecid ?? "") else {
            return
        }
        campaign.processRequest(url: url, payload: "", event: event)
    }
    
    ///Dispatches an event with message `id` and action `click`. This is to mark that a notification is interacted by user.
    /// - Parameters:
    ///    - action: String containing the action value. The `action` should be either `1 or 2`
    ///    - deliveryId: The hex encoded deliveryId.
    ///    - campaign: An instance of `Campaign`. This is used for dispatching the response event.
    private func dispatchMessageEvent(action: String, deliveryId: String, campaign: Campaign) {
        
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
            
        campaign.dispatchEvent(eventName: "DataForMessageRequest", eventType: EventType.campaign, eventSource: EventSource.responseContent, eventData: contextData)
                
    }
    
    private func buildTrackingUrl(host: String,
                          broadLogId: String,
                          deliveryId: String,
                          action: String,
                          ecid: String) -> URL? {
        
        guard !host.isEmpty, !broadLogId.isEmpty, !deliveryId.isEmpty, !action.isEmpty, !ecid.isEmpty else {
            return nil
        }
        
        var urlComponent = URLComponents()
        urlComponent.scheme = "https"
        urlComponent.host = host
        urlComponent.path = "r"
        urlComponent.queryItems = [
            URLQueryItem(name: "id", value: "\(broadLogId),\(deliveryId),\(action)"),
            URLQueryItem(name: "mcId", value: ecid)
        ]
        
        return urlComponent.url
    }
}
//        processRequest(url, "", campaignState, event);
