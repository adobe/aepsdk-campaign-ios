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
    public var metadata: [String: String]?
    public let runtime: ExtensionRuntime
    var state: CampaignState?
    typealias EventDispatcher = (_ eventName: String, _ eventType: String, _ eventSource: String, _ contextData: [String: Any]?) -> Void

    private let dependencies: [String] = [
        CampaignConstants.Configuration.EXTENSION_NAME,
        CampaignConstants.Identity.EXTENSION_NAME
    ]

    /// Initializes the Campaign extension
    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        super.init()
        if let hitQueue = setupHitQueue() {
            state = CampaignState(hitQueue: hitQueue)
        }
    }

    /// Invoked when the Campaign extension has been registered by the `EventHub`
    public func onRegistered() {
        registerListener(type: EventType.campaign, source: EventSource.requestContent, listener: handleCampaignEvents)
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleLifecycleEvents)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationEvents)
        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleHubSharedStateEvent)
        registerListener(type: EventType.genericData, source: EventSource.os, listener: handleGenericDataEvent)
    }

    /// Invoked when the Campaign extension has been unregistered by the `EventHub`, currently a no-op.
    public func onUnregistered() {

    }

    /// Called before each `Event` processed by the Campaign extension
    /// - Parameter event: event that will be processed next
    /// - Returns: *true* if Configuration and Identity shared states are available
    public func readyForEvent(_ event: Event) -> Bool {
        guard getSharedState(extensionName: CampaignConstants.Configuration.EXTENSION_NAME, event: event)?.status == .set, getSharedState(extensionName: CampaignConstants.Identity.EXTENSION_NAME, event: event)?.status == .set  else {
            return false
        }
        return true
    }

    /// Handles events of type `Campaign` and source `requestContent`
    private func handleCampaignEvents(event: Event) {

    }

    /// Handles events of type `Lifecycle` and source `responseContent`
    private func handleLifecycleEvents(event: Event) {
        guard let state = state else {
            Log.warning(label: LOG_TAG, "\(#function) - Unable to process request. CampaignState is nil.")
            return
        }
        state.queueRegistrationRequest(event: event)
    }

    /// Handles events of type `Configuration` and source `responseContent`
    private func handleConfigurationEvents(event: Event) {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }
        state?.update(dataMap: sharedStates)

        if state?.privacyStatus == .optedOut {
            // handle opt out
        }
    }

    /// Handles `Shared state` update events
    private func handleHubSharedStateEvent(event: Event) {

    }

    /// Handles events of type `Generic Data` and source `os`
    private func handleGenericDataEvent(event: Event) {
        guard let state = state else {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to handle event '\(event.id)'. Campaign State is nil.")
            return
        }

        MessageInteractionTracker.processMessageInformation(event: event, state: state, eventDispatcher: dispatchEvent(eventName:eventType:eventSource:eventData:))
    }

    /// Dispatches an event with provided `Name`, `Type`, `Source` and `Data`.
    ///  - Parameters:
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
}
