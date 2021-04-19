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

@objc(AEPCampaign)
public class Campaign: NSObject, Extension {
    
    private let LOG_TAG = "Campaign"
    public var name = CampaignConstants.EXTENSION_NAME
    public var friendlyName = CampaignConstants.FRIENDLY_NAME
    public static var extensionVersion = CampaignConstants.EXTENSION_VERSION
    public var metadata: [String : String]?
    public let runtime: ExtensionRuntime
    private var campaignState: CampaignState    
    
    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        campaignState = CampaignState()
        super.init()
    }
    
    public func onRegistered() {
        registerListener(type: EventType.campaign, source: EventSource.requestContent, listener: handleCampaignEvents)
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleLifecycleEvents)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationEvents)
        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleHubSharedStateEvent)
        registerListener(type: EventType.genericData, source: EventSource.os, listener: handleGenericDataEvent)
    }
    
    public func onUnregistered() {}
    
    public func readyForEvent(_ event: Event) -> Bool {
        let configSharedStateStatus = getSharedState(extensionName: CampaignConstants.Configuration.EXTENSION_NAME, event: event)?.status ?? .none
        return configSharedStateStatus == .set
    }
    
    ///Handles events of type `Campaign`
    private func handleCampaignEvents(event: Event){
        
    }
    
    ///Handles events of type `Lifecycle`
    private func handleLifecycleEvents(event: Event){
        
    }
    
    ///Handles events of type `Configuration`
    private func handleConfigurationEvents(event: Event){
        
    }
    
    ///Handles `Hub Shared state` events
    private func handleHubSharedStateEvent(event: Event){
        
    }
    
    ///Handles `Generic Data` events
    private func handleGenericDataEvent(event: Event){
        MessageInteractionTracker.processMessageInformation(event: event, state: campaignState, campaign: self)
    }
    
    func dispatchEvent(eventName name: String, eventType type: String, eventSource source: String, eventData data: [String: Any]?) {
        
        let event = Event(name: name, type: type, source: source, data: data)
        dispatch(event: event)
    }
    
    func processRequest(url: URL, payload: String, event: Event) {
        
        // check if this request is a registration request by checking for the presence of a payload and if it is a registration request, determine if it should be sent.
        guard !payload.isEmpty else {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to process request. Payload is empty.")
            return
        }
        
        guard shouldSendRegistrationRequest() else {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to process request. shouldSendRegistrationRequest is return false.")
            return
        }
                
        ///TODO: Implement persisting the Campaign Hit.

        //            final CampaignHitsDatabase database = getCampaignHitsDatabase();
        //
        //            if (database != null) {
        //                // create then queue the campaign hit
        //                CampaignHit campaignHit = new CampaignHit();
        //                campaignHit.url = url;
        //                campaignHit.body = payload;
        //                campaignHit.timeout = campaignState.getCampaignTimeout();
        //                database.queue(campaignHit, event.getTimestamp(), campaignState.getMobilePrivacyStatus());
        //
        //                Log.debug(CampaignConstants.LOG_TAG,
        //                          "processRequest - Campaign Request Queued with url (%s) and body (%s)", url, payload);
        //            } else {
        //                Log.warning(CampaignConstants.LOG_TAG,
        //                            "Campaign database is not initialized. Unable to queue Campaign Request.");
        //            }
        
    }
    
    private func shouldSendRegistrationRequest() -> Bool{
        //TODO:: Implement this
    return false
    }
}
