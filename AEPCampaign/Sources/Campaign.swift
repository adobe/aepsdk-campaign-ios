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
    let dispatchQueue: DispatchQueue
    private var hasCachedRulesLoaded = false
    private var rulesEngine: LaunchRulesEngine
    private var linkageFields: String?

    private let dependencies: [String] = [
        CampaignConstants.Configuration.EXTENSION_NAME,
        CampaignConstants.Identity.EXTENSION_NAME
    ]

    /// Initializes the Campaign extension
    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
        dispatchQueue = DispatchQueue(label: "\(CampaignConstants.EXTENSION_NAME).dispatchqueue")
        rulesEngine = LaunchRulesEngine(name: "\(CampaignConstants.EXTENSION_NAME).rulesengine", extensionRuntime: runtime)
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
        //The wildcard listener for Campaign Rules Engine Processing
        registerListener(type: EventType.wildcard, source: EventSource.wildcard, listener: handleWildCardEvents(event:))
    }

    /// Invoked when the Campaign extension has been unregistered by the `EventHub`, currently a no-op.
    public func onUnregistered() {}

    /// Called before each `Event` processed by the Campaign extension
    /// - Parameter event: event that will be processed next
    /// - Returns: *true* if Configuration and Identity shared states are available
    public func readyForEvent(_ event: Event) -> Bool {
        return getSharedState(extensionName: CampaignConstants.Configuration.EXTENSION_NAME, event: event)?.status == .set && getSharedState(extensionName: CampaignConstants.Identity.EXTENSION_NAME, event: event)?.status == .set
    }

    /// Handles events of type `Campaign`
    private func handleCampaignEvents(event: Event) {
        Log.trace(label: LOG_TAG, "An event of type \(event.type) has received.")
        guard let details = event.consequenceDetails, !details.isEmpty else {
            Log.warning(label: LOG_TAG, "\(#function) - Unable to handle Campaign event, detail dictionary is nil or empty.")
            return
        }
        let consequence = RuleConsequence(id: event.consequenceId ?? "", type: event.consequenceType ?? "", details: details)
        let template = details[CampaignConstants.EventDataKeys.RulesEngine.Detail.TEMPLATE] as? String
        if template == CampaignConstants.Campaign.MessagePayload.TEMPLATE_LOCAL {
            Log.debug(label: LOG_TAG, "\(#function) - Received a Campaign Request content event containing a local notification. Scheduling the received local notification.")
            guard let message = LocalNotificationMessage.createMessageObject(consequence: consequence, state: state, eventDispatcher: dispatchEvent(eventName:eventType:eventSource:eventData:)) else {
                return
            }
            message.showMessage()
        } else if template == CampaignConstants.Campaign.MessagePayload.TEMPLATE_FULLSCREEN {
            Log.debug(label: LOG_TAG, "\(#function) - Received a Campaign Request content event containing a fullscreen message.")
            guard let message = CampaignFullscreenMessage.createMessageObject(consequence: consequence, state: state, eventDispatcher: dispatchEvent(eventName:eventType:eventSource:eventData:)) else {
                return
            }
            message.showMessage()
        } else if template == CampaignConstants.Campaign.MessagePayload.TEMPLATE_ALERT {
            Log.debug(label: LOG_TAG, "\(#function) - Received a Campaign Request content event containing an alert message.")
            guard let message = AlertMessage.createMessageObject(consequence: consequence, state: state, eventDispatcher: dispatchEvent(eventName:eventType:eventSource:eventData:)) else {
                return
            }
            message.showMessage()
        }
    }

    /// Handles events of type `Lifecycle`
    private func handleLifecycleEvents(event: Event) {
        state.queueRegistrationRequest(event: event)
    }

    ///Handles the wild card `Events` for Rules Engine processing.
    private func handleWildCardEvents(event: Event) {
        let event = rulesEngine.process(event: event)
        //dispatch(event: event)
    }

    ///Handles events of type `Configuration`
    private func handleConfigurationEvents(event: Event) {
        let oldPrivacyStatus = state.privacyStatus
        updateCampaignState(event: event)
        if state.privacyStatus != oldPrivacyStatus {
            handlePrivacyStatusChange()
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

    ///Updates the `CampaignState` with the shared state of other required extensions
    private func updateCampaignState(event: Event) {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }
        state.update(dataMap: sharedStates)
    }

    ///Handles the privacy status
    private func handlePrivacyStatusChange() {
        if state.privacyStatus == .optedOut {
            // handle opt out
            return
        }

        if state.privacyStatus == PrivacyStatus.optedIn {
//            let fakeUrl = URL(string: "https://assets.adobedtm.com/94f571f308d5/0d8e122e1a29/launch-dad327eb0536-development-rules.zip")
//            var campaignRulesDownloader = CampaignRulesDownloader(fileUnzipper: FileUnzipper(), ruleEngine: self.rulesEngine)
//            campaignRulesDownloader.loadRulesFromUrl(rulesUrl: fakeUrl!, linkageFieldHeaders: nil, state: self.state)
            triggerRulesDownload()
        }
    }

    ///Triggers the rules downloading and caching.
    private func triggerRulesDownload() {
        dispatchQueue.async { [weak self] in
            //Download rules from the remote URL and cache them.
            guard let self = self else {return}
            guard let url = self.state.campaignRulesDownloadUrl else {
                Log.warning(label: self.LOG_TAG, "\(#function) - Unable to download Campaign Rules. URL is nil. Cached rules will be used if present.")
                return
            }
            let campaignRulesDownloader = CampaignRulesDownloader(fileUnzipper: FileUnzipper(), ruleEngine: self.rulesEngine, campaignMessageAssetsCache: CampaignMessageAssetsCache(dispatchQueue: self.dispatchQueue), dispatchQueue: self.dispatchQueue)
            var linkageFieldsHeader: [String: String]?
            if let linkageFields = self.linkageFields {
                linkageFieldsHeader = [
                    CampaignConstants.Campaign.LINKAGE_FIELD_NETWORK_HEADER: linkageFields
                ]
            }
            campaignRulesDownloader.loadRulesFromUrl(rulesUrl: url, linkageFieldHeaders: linkageFieldsHeader, state: self.state)
        }
    }

    ///Loads the Cached Campaign rules on receiving the Configuration event first time.
    private func loadCachedRules() {
        if !hasCachedRulesLoaded {
            Log.trace(label: LOG_TAG, "\(#function) - Attempting to load the Cached Campaign Rules.")
            dispatchQueue.async { [weak self] in
                guard let self = self else {return}
                guard let urlString = self.state.getRulesUrlFromDataStore() else {
                    Log.debug(label: self.LOG_TAG, "\(#function) - Unable to load cached rules. Couldn't get valid rules URL from Datastore")
                    return
                }
                let campaignRulesDownloader = CampaignRulesDownloader(fileUnzipper: FileUnzipper(), ruleEngine: self.rulesEngine)
                campaignRulesDownloader.loadRulesFromCache(rulesUrlString: urlString)
                self.hasCachedRulesLoaded = true
            }
        }
    }
}
