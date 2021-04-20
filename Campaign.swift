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
    
    private static let LOG_TAG = "Campaign"
    
    public var name = CampaignConstants.EXTENSION_NAME
    public var friendlyName = CampaignConstants.FRIENDLY_NAME
    public static var extensionVersion = CampaignConstants.EXTENSION_VERSION
    public var metadata: [String : String]?
    public let runtime: ExtensionRuntime
    private var state: CampaignState?
    
    private let dependencies: [String] = [
        CampaignConstants.Configuration.EXTENSION_NAME,
        CampaignConstants.Identity.EXTENSION_NAME
    ]
    
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
        if shouldSendRegistrationRequest(timestamp: event.timestamp.timeIntervalSince1970) {
            state?.queueRegistrationRequest(event: event)
        }
    }
    
    ///Handles events of type `Configuration`
    private func handleConfigurationEvents(event: Event){
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }
        state?.update(dataMap: sharedStates)

        if state?.privacyStatus == .optedOut {
            // handle opt out
        }
    }
    
    ///Handles `Hub Shared state` events
    private func handleHubSharedStateEvent(event: Event){
        
    }
    
    ///Handles `Generic Data` events
    private func handleGenericDataEvent(event: Event){
        
    }
    
    /// Sets up the `PersistentHitQueue` to handle `CampaignHit`s
    private func setupHitQueue() -> HitQueuing? {
        guard let dataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: name) else {
            Log.error(label: Self.LOG_TAG, "\(#function) - Failed to create DataQueue, Campaign could not be initialized")
            return nil
        }
        guard let state = self.state else {
            Log.error(label: Self.LOG_TAG, "\(#function) - Failed to create DataQueue, the Campaign State is nil")
            return nil
        }
        let hitProcessor = CampaignHitProcessor(timeout: state.campaignTimeout, responseHandler: handleSuccessfulNetworkRequest(hit:))
        return PersistentHitQueue(dataQueue: dataQueue, processor: hitProcessor)
    }
    
    /// Invoked by the `CampaignHitProcessor` each time we successfully send a Campaign network request.
    /// - Parameter hit: The `CampaignHit` which was successfully sent
    private func handleSuccessfulNetworkRequest(hit: CampaignHit) {
        state?.updateDatastoreWithSuccessfulRegistrationInfo(hit: hit)
    }
    
    /// Determines if a registration request should be sent to Campaign.
    /// - Parameter timestamp: The Lifecycle Event timestamp
    /// - Returns: A `Bool` containing true if the registration request should be sent, false otherwise.
    private func shouldSendRegistrationRequest(timestamp: TimeInterval) -> Bool {
        // quick out if registration requests are paused
        if let registrationPaused = state?.campaignRegistrationPaused, registrationPaused == true {
            Log.debug(label: Self.LOG_TAG, "\(#function) - Registration requests are paused.")
            return false
        }

        // if there is no ecid or timestamp in the datastore then a successful registration has not
        // yet occurred.
        guard let retrievedEcid = state?.dataStore.getString(key: CampaignConstants.Campaign.Datastore.ECID_KEY), let retrievedTimestamp = state?.dataStore.getDouble(key: CampaignConstants.Campaign.Datastore.REGISTRATION_TIMESTAMP_KEY) else {
            Log.debug(label: Self.LOG_TAG, "\(#function) - There is no experience cloud id or registration timestamp currently stored in the datastore. The registration request will be sent.")
            return true
        }
              
        if let currentEcid = state?.ecid, currentEcid == retrievedEcid {
            Log.debug(label: Self.LOG_TAG, "\(#function) - The current experience cloud id is unchanged. The registration request will not be sent.")
            return false
        }
        
        if let registrationDelay = state?.campaignRegistrationDelay, timestamp - retrievedTimestamp < registrationDelay {
            Log.debug(label: Self.LOG_TAG, "\(#function) - The registration delay has not elapsed. The registration request will not be sent.")
            return false
        }
        
        Log.debug(label: Self.LOG_TAG, "\(#function) - The registration request will be sent because the registration delay has elapsed or the ecid has changed since the last successful registration request.")
        return true
    }
}
