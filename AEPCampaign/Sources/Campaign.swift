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
    var state: CampaignState
    typealias EventDispatcher = (_ eventName: String, _ eventType: String, _ eventSource: String, _ contextData: [String: Any]?) -> Void

    private let dependencies: [String] = [
        CampaignConstants.Configuration.EXTENSION_NAME,
        CampaignConstants.Identity.EXTENSION_NAME
    ]

    /// Initializes the Campaign extension
    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        self.state = CampaignState()
        super.init()
    }

    /// Invoked when the Campaign extension has been registered by the `EventHub`
    public func onRegistered() {
        registerListener(type: EventType.campaign, source: EventSource.requestContent, listener: handleCampaignEvents)
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleLifecycleEvents)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationEvents)
        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleSharedStateUpdateEvents)
        registerListener(type: EventType.genericData, source: EventSource.os, listener: handleGenericDataEvents)
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

    /// Handles events of type `Campaign`
    private func handleCampaignEvents(event: Event) {
        guard let consequenceDict = event.triggeredConsequence, !consequenceDict.isEmpty else {
            Log.warning(label: LOG_TAG, "\(#function) - Unable to handle Campaign event, consequence is nil or empty.")
            return
        }
        guard let detail = consequenceDict[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL] as? [String: Any], !detail.isEmpty else {
            Log.warning(label: LOG_TAG, "\(#function) - Unable to handle Campaign event, detail dictionary is nil or empty.")
            return
        }
        let consequence = CampaignRuleConsequence(id: consequenceDict[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_ID] as? String ?? "", type: consequenceDict[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_TYPE] as? String ?? "", assetsPath: consequenceDict[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_ASSETS_PATH] as? String ?? "", detail: detail)
        let template = detail[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_TEMPLATE] as? String
        if template == CampaignConstants.Campaign.MessagePayload.TEMPLATE_LOCAL {
            Log.debug(label: LOG_TAG, "\(#function) - Received a Campaign Request content event containing a local notification. Scheduling the received local notification.")
            guard let message = LocalNotificationMessage.createMessageObject(consequence: consequence, state: state, eventDispatcher: dispatchEvent(eventName:eventType:eventSource:eventData:)) else {
                return
            }
            message.showMessage()
        }
    }

    /// Handles events of type `Lifecycle`
    private func handleLifecycleEvents(event: Event) {
        state.queueRegistrationRequest(event: event)
    }

    /// Handles events of type `Configuration`
    private func handleConfigurationEvents(event: Event) {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }
        state.update(dataMap: sharedStates)

        if state.privacyStatus == .optedOut {
            // handle opt out
        }
    }

    /// Handles `Shared state` update events
    private func handleSharedStateUpdateEvents(event: Event) {

    }

    /// Handles events of type `Generic Data`
    private func handleGenericDataEvents(event: Event) {
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
}
