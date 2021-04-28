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
    var state: CampaignState?
    typealias EventDispatcher = (_ eventName: String, _ eventType: String, _ eventSource: String, _ contextData: [String:Any]?) -> Void
    let dispatchQueue: DispatchQueue
    let campaignRulesDownloader = CampaignRulesDownloader(fileUnzipper: FileUnzipper())
    private let rulesEngine: LaunchRulesEngine!
    private var hasCachedRulesLoaded = false
    
    
    private let dependencies: [String] = [
        CampaignConstants.Configuration.EXTENSION_NAME,
        CampaignConstants.Identity.EXTENSION_NAME
    ]
    
    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        dispatchQueue = DispatchQueue(label: friendlyName)
        rulesEngine = LaunchRulesEngine(name: friendlyName, extensionRuntime: runtime)
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
        guard getSharedState(extensionName: CampaignConstants.Configuration.EXTENSION_NAME, event: event)?.status == .set, getSharedState(extensionName: CampaignConstants.Identity.EXTENSION_NAME, event: event)?.status == .set  else {
            return false
        }
        return true
    }
    
    ///Handles events of type `Campaign`
    private func handleCampaignEvents(event: Event){
        
    }
    
    ///Handles events of type `Lifecycle`
    private func handleLifecycleEvents(event: Event){
        guard let state = state else {
            Log.warning(label: LOG_TAG, "\(#function) - Unable to process request. CampaignState is nil.")
            return
        }
        // state.queueRegistrationRequest(event: event)
    }
    
    ///Handles events of type `Configuration`
    private func handleConfigurationEvents(event: Event){
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }
        state?.update(dataMap: sharedStates)
        if !hasCachedRulesLoaded {
            Log.trace(label: LOG_TAG, "\(#function) - Loading the Cached Campaign Rules.")
            dispatchQueue.async { [weak self] in
                self?.loadCachedRules()
            }
        }

        if state?.privacyStatus == .optedOut {
            // handle opt out
        }
        
        dispatchQueue.async { [weak self] in
            self?.downloadRules()
        }
    }
    
    ///Handles `Hub Shared state` events
    private func handleHubSharedStateEvent(event: Event){
        
    }
    
    ///Handles `Generic Data` events
    private func handleGenericDataEvent(event: Event) {
        guard let state = state else {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to handle event '\(event.id)'. Campaign State is nil.")
            return
        }
        
        MessageInteractionTracker.processMessageInformation(event: event, state: state, eventDispatcher: dispatchEvent(eventName:eventType:eventSource:eventData:))
    }
    
    ///Dispatches an event with provided `Name`, `Type`, `Source` and `Data`.
    /// - Parameters:
    ///    - eventName: Name of event
    ///    - eventType: `EventType` for event
    ///    - eventSource: `EventSource` for event
    ///    - eventData: `EventData` for event
    func dispatchEvent(eventName name: String, eventType type: String, eventSource source: String, eventData data: [String: Any]?) {
        
        let event = Event(name: name, type: type, source: source, data: data)
        dispatch(event: event)
    }

    /// Invoked by the `CampaignHitProcessor` each time we successfully send a Campaign network request.
    /// - Parameter hit: The `CampaignHit` which was successfully sent
    private func handleSuccessfulNetworkRequest(hit: CampaignHit) {
        state?.updateDatastoreWithSuccessfulRegistrationInfo(timestamp: hit.timestamp)
    }
            
    /// Sets up the `PersistentHitQueue` to handle `CampaignHit`s
    private func setupHitQueue() -> HitQueuing? {
        guard let dataQueue = ServiceProvider.shared.dataQueueService.getDataQueue(label: name) else {
            Log.error(label: LOG_TAG, "\(#function) - Failed to create PersistentHitQueue, Campaign could not be initialized")
            return nil
        }
        
        guard let state = self.state else {
            Log.error(label: LOG_TAG, "\(#function) - Failed to create PersistentHitQueue, the Campaign State is nil")
            return nil
        }
        
        let hitProcessor = CampaignHitProcessor(timeout: state.campaignTimeout, responseHandler: handleSuccessfulNetworkRequest(hit:))
        return PersistentHitQueue(dataQueue: dataQueue, processor: hitProcessor)
    }
    
    ///Load the `Campaign` rules from the cache. It happens only once after the  Configuration Response event is received.
    private func loadCachedRules() {
        guard let mciasServer = state?.campaignMciasServer, let campaignServer = state?.campaignServer, let propertyId = state?.campaignPropertyId, let ecid = state?.ecid else {
            return
        }
        
        if let rulesUrl = URL.getRulesDownloadUrl(mciasServer: mciasServer, campaignServer: campaignServer, propertyId: propertyId, ecid: ecid) {
            rulesEngine.replaceRulesWithCache(from: rulesUrl.absoluteString)
        }
    }
    
    ///Download the `Campaign` Rules, cache them and load them in `Rules Engine`.
    private func downloadRules(){
        campaignRulesDownloader.loadRulesFromUrl(rulesUrl: "") { data in
            
        }
    }
}
