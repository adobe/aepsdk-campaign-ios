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
    private var state: CampaignState?
    private let nameCollectionDataStore = NamedCollectionDataStore(name: CampaignConstants.DATASTORE_NAME)
    
    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()
        if let hitQueue = setupHitQueue() {
            state = CampaignState(hitQueue: hitQueue)
        }
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
        guard let state = state else {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to handle event '\(event.id)'. Campaign State is nil.")
            return
        }
        
        MessageInteractionTracker.processMessageInformation(event: event, state: state, campaign: self)
    }
    
    func dispatchEvent(eventName name: String, eventType type: String, eventSource source: String, eventData data: [String: Any]?) {
        
        let event = Event(name: name, type: type, source: source, data: data)
        dispatch(event: event)
    }
    
    func processRequest(url: URL, payload: String, event: Event) {
        
        guard let state = state else {
            Log.warning(label: LOG_TAG, "\(#function) - Unable to process request. CampaignState is nil.")
            return
        }
        
        // check if this request is a registration request by checking for the presence of a payload and if it is a registration request, determine if it should be sent.
        if !payload.isEmpty { //Registration request
            guard shouldSendRegistrationRequest(eventTimeStamp: event.timestamp.timeIntervalSince1970) else {
                Log.warning(label: LOG_TAG, "\(#function) - Unable to process request.")
                return
            }
        }
        
        state.hitQueue.queue(url: url, payload: payload, timestamp: event.timestamp.timeIntervalSince1970, privacyStatus: state.privacyStatus)
    }
    
    private func shouldSendRegistrationRequest(eventTimeStamp: TimeInterval) -> Bool {
        guard let state = state, let ecid = state.ecid, let registrationDelay = state.campaignRegistrationDelay else {
            Log.debug(label: LOG_TAG, "\(#function) - Returning false. Required filled in Campaign State are missing.")
            return false
        }
        
        guard !(state.campaignRegistrationPaused ?? false) else {
            Log.debug(label: LOG_TAG, "\(#function) - Returning false, Registration requests are paused.")
            return false
        }
        
        if nameCollectionDataStore.getString(key: CampaignConstants.Campaign.Datastore.ECID_KEY, fallback: "") != ecid {
            Log.debug(label: LOG_TAG, "\(#function) - The current ecid '\(ecid)' is new, sending the registration request.")
            nameCollectionDataStore.set(key: CampaignConstants.Campaign.Datastore.ECID_KEY, value: ecid)
            return true
        }
        
        let retrievedTimeStamp = nameCollectionDataStore.getLong(key: CampaignConstants.Campaign.Datastore.REGISTRATION_TIMESTAMP_KEY) ?? Int64(CampaignConstants.Campaign.DEFAULT_TIMESTAMP_VALUE)
        
        if eventTimeStamp - TimeInterval(retrievedTimeStamp) >= registrationDelay {
            Log.debug(label: LOG_TAG, "\(#function) - Registration delay of '\(registrationDelay)' seconds has elapsed. Sending the Campaign registration request.")
            return true
        }
        
        Log.debug(label: LOG_TAG, "\(#function) - The registration request will not be sent because the registration delay of \(registrationDelay) seconds has not elapsed.")
        return false
    }
    
    /// Sets up the `PersistentHitQueue` to handle `CampaignHit`s
    private func setupHitQueue() -> HitQueuing? {
        guard let dataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: name) else {
            Log.error(label: LOG_TAG, "\(#function) - Failed to create DataQueue, Campaign could not be initialized")
            return nil
        }
        
        let hitProcessor = CampaignHitProcessor()
        return PersistentHitQueue(dataQueue: dataQueue, processor: hitProcessor)
    }
}
