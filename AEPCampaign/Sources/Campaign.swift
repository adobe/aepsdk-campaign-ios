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

@objc(AEPMobileCampaign)
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
    private var hasToDownloadRules = false
    var rulesEngine: LaunchRulesEngine
    private var linkageFields: String?
    private var fullscreenMessage: CampaignFullscreenMessage?

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
        registerListener(type: EventType.campaign, source: EventSource.requestIdentity, listener: handleCampaignEvents)
        registerListener(type: EventType.campaign, source: EventSource.requestReset, listener: handleCampaignEvents)
        registerListener(type: EventType.lifecycle, source: EventSource.responseContent, listener: handleLifecycleEvents)
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: handleConfigurationEvents)
        registerListener(type: EventType.genericData, source: EventSource.os, listener: handleGenericDataEvents)
        registerListener(type: EventType.hub, source: EventSource.sharedState, listener: handleHubSharedState(event:))
        // The wildcard listener for Rules Engine Processing
        registerListener(type: EventType.wildcard, source: EventSource.wildcard, listener: handleWildCardEvents)
        registerListener(type: EventType.rulesEngine, source: EventSource.responseContent, listener: handleRulesEngineResponseEvent)
    }

    /// Invoked when the Campaign extension has been unregistered by the `EventHub`, currently a no-op.
    public func onUnregistered() {}

    /// Called before each `Event` processed by the Campaign extension
    /// - Parameter event: event that will be processed next
    /// - Returns: `true` if Configuration and Identity shared states are available
    public func readyForEvent(_ event: Event) -> Bool {
        return getSharedState(extensionName: CampaignConstants.Configuration.EXTENSION_NAME, event: event)?.status == .set && getSharedState(extensionName: CampaignConstants.Identity.EXTENSION_NAME, event: event)?.status == .set
    }

    /// Handles events of type `Campaign`
    /// - Parameter event: the Campaign `Event` to be handled
    private func handleCampaignEvents(event: Event) {
        Log.trace(label: self.LOG_TAG, "An event of type \(event.type) has been received.")
        dispatchQueue.async {[weak self] in
            guard let self = self else {return}
            switch event.source {
            case EventSource.requestIdentity:
                let isSuccessful = self.extractLinkageFields(event: event)
                if isSuccessful {
                    self.clearCachedRules()
                    self.updateCampaignState(event: event)
                    self.triggerRulesDownload()
                } else {
                    Log.debug(label: self.LOG_TAG, "\(#function) - Dropping Campaign RequestIdentity event '\(event.name)'. Unable to extract Linkage fields.")
                }

            case EventSource.requestReset:
                self.resetRules()
                self.updateCampaignState(event: event)
                self.triggerRulesDownload()

            default:
                Log.debug(label: self.LOG_TAG, "\(#function) - Dropping Campaign event '\(event.id)'. The event source '\(event.source)' is unknown.")
            }
        }
    }

    /// Handles events of type `Lifecycle`
    /// - Parameter event: the Lifecycle `Event` to be handled
    private func handleLifecycleEvents(event: Event) {
        Log.trace(label: self.LOG_TAG, "An event of type \(event.type) has been received.")
        dispatchQueue.async { [weak self] in
            guard let self = self else {return}
            self.updateCampaignState(event: event)
            self.state.queueRegistrationRequest(event: event)
        }
    }

    /// A wildcard listener for all the events. Pass the received events to `Rules Engine` for processing.
    /// - Parameter event: the Wildcard `Event` to be handled
    private func handleWildCardEvents(event: Event) {
        _ = rulesEngine.process(event: event)
    }

    /// Handles the `Rules engine response` event, when a rule matches
    /// - Parameter event: the Rules Engine `Event` to be handled
    private func handleRulesEngineResponseEvent(event: Event) {
        Log.trace(label: self.LOG_TAG, "An event of type \(event.type) has been received.")
        dispatchQueue.async { [weak self] in
            guard let self = self else {return}
            guard let details = event.consequenceDetails, !details.isEmpty else {
                Log.warning(label: self.LOG_TAG, "\(#function) - Unable to handle Rules Response event, detail dictionary is nil or empty.")
                return
            }
            guard let template = details[CampaignConstants.EventDataKeys.RulesEngine.Detail.TEMPLATE] as? String else {
                Log.debug(label: self.LOG_TAG, "\(#function) Dropping triggered consequence event '\(event.id)'. Template type is missing.")
                return
            }
            guard let iamType = IAMType(rawValue: template) else {
                Log.debug(label: self.LOG_TAG, "\(#function) Dropping triggered consequence event '\(event.id)'. Template type is unknown.")
                return
            }

            let consequence = RuleConsequence(id: event.consequenceId ?? "", type: event.consequenceType ?? "", details: details)

            switch iamType {
            case .fullscreen:
                self.showFullScreenMessage(forConsequence: consequence)

            case .alert:
                self.showAlertMessage(forConsequence: consequence)

            case .local:
                self.showLocalNotification(forConsequence: consequence)
            }
        }
    }

    /// Handles `Configuration Response` events
    /// - Parameter event: the Configuration `Event` to be handled
    private func handleConfigurationEvents(event: Event) {
        Log.trace(label: self.LOG_TAG, "An event of type '\(event.type)' has been received.")
        dispatchQueue.async { [weak self] in
            guard let self = self else {return}
            self.updateCampaignState(event: event)
            if !self.hasCachedRulesLoaded {
                self.loadCachedRules()
            }
            if self.state.privacyStatus == PrivacyStatus.optedOut {
                self.handlePrivacyOptOut()
                return
            }
            if self.state.canDownloadRules() {
                self.hasToDownloadRules = false
                self.triggerRulesDownload()
            } else {
                // Cannot download rules now. Most probably because Identity shared state hasn't received yet and we don't have ECID. Will try to download rules after receiving Identity shared state.
                self.hasToDownloadRules = true
            }
        }
    }

    /// Handles `Identity` shared state updates
    /// - Parameter event: the Identity `Event` to be handled
    private func handleHubSharedState(event: Event) {
        guard let stateOwner = event.data?[CampaignConstants.EventDataKeys.STATE_OWNER] as? String, stateOwner == CampaignConstants.Identity.EXTENSION_NAME else {
            return
        }

        guard hasToDownloadRules else {
            return
        }

        dispatchQueue.async { [weak self] in
            guard let self = self else {return}
            self.updateCampaignState(event: event)
            self.hasToDownloadRules = false
            self.triggerRulesDownload()
        }
    }

    /// Handles `Generic Data OS` events
    /// - Parameter event: the Generic Data `Event` to be handled
    private func handleGenericDataEvents(event: Event) {
        Log.trace(label: self.LOG_TAG, "An event of type \(event.type) has been received.")
        dispatchQueue.async { [weak self] in
            guard let self = self else {return}
            self.updateCampaignState(event: event)
            MessageInteractionTracker.processMessageInformation(event: event, state: self.state, eventDispatcher: self.dispatchEvent(eventName:eventType:eventSource:eventData:))
        }
    }

    /// Dispatches an event with provided `Name`, `Type`, `Source` and `Data`.
    ///  - Parameters:
    ///    - eventName: Name of event
    ///    - eventType: `EventType` for event
    ///    - eventSource: `EventSource` for event
    ///    - eventData: `EventData` for event
    func dispatchEvent(eventName name: String, eventType type: String, eventSource  source: String, eventData data: [String: Any]?) {
        let event = Event(name: name, type: type, source: source, data: data)
        dispatch(event: event)
    }

    /// Updates the `CampaignState` with the shared state of other required extensions
    /// - Parameter event: the `Event`containing the shared state of other required extensions
    private func updateCampaignState(event: Event) {
        var sharedStates = [String: [String: Any]?]()
        for extensionName in dependencies {
            sharedStates[extensionName] = runtime.getSharedState(extensionName: extensionName, event: event, barrier: true)?.value
        }
        state.update(dataMap: sharedStates)
    }

    /// Handles the privacy opt-out. The function takes the following actions to process the opt-out:
    /// 1). Resets the linkage field to empty string
    /// 2). Removes all the registered rules
    /// 3). Deletes all the cached assets for the rules
    /// 4). Remove the rules URL from the data store
    private func handlePrivacyOptOut() {
        Log.debug(label: LOG_TAG, "\(#function) - Process the Privacy opt-out")
        resetRules()
        state.removeRuleUrlFromDatastore()
    }

    /// Triggers the rules download and if successful, caches the downloaded rules.
    private func triggerRulesDownload() {
        guard let url = self.state.campaignRulesDownloadUrl else {
            Log.warning(label: self.LOG_TAG, "\(#function) - Unable to download Campaign Rules. URL is nil. Cached rules will be used if present.")
            return
        }
        let campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: CampaignRulesCache(), ruleEngine: self.rulesEngine, campaignMessageAssetsCache: CampaignMessageAssetsCache(), dispatchQueue: self.dispatchQueue)
        var linkageFieldsHeader: [String: String]?
        if let linkageFields = self.linkageFields {
            linkageFieldsHeader = [
                CampaignConstants.Campaign.LINKAGE_FIELD_NETWORK_HEADER: linkageFields
            ]
        }
        campaignRulesDownloader.loadRulesFromUrl(rulesUrl: url, linkageFieldHeaders: linkageFieldsHeader, state: self.state)
    }

    /// Loads the cached Campaign rules upon receiving the Configuration event for the first time.
    private func loadCachedRules() {
        if !hasCachedRulesLoaded {
            Log.trace(label: LOG_TAG, "\(#function) - Attempting to load the Cached Campaign Rules.")
            guard let urlString = self.state.getRulesUrlFromDataStore() else {
                Log.debug(label: self.LOG_TAG, "\(#function) - Unable to load cached rules. Couldn't get valid rules URL from Datastore")
                return
            }
            let campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: CampaignRulesCache(), ruleEngine: self.rulesEngine)
            campaignRulesDownloader.loadRulesFromCache(rulesUrlString: urlString)
            self.hasCachedRulesLoaded = true

        }
    }

    /// Extracts the linkage fields from the passed in event's data.
    /// - Parameter event: the Campaign `Event`containing linkage fields
    /// - Returns `true` if the event contained linkage fields, otherwise returns `false`
    private func extractLinkageFields(event: Event) -> Bool {
        guard let linkageFields = event.linkageFields else {
            return false
        }
        self.linkageFields = linkageFields
        return true
    }

    /// Reset the Campaign Extension rules and linkage fields.
    private func resetRules() {
        Log.debug(label: LOG_TAG, "\(#function) - Clearing set linkage fields, the currently loaded campaign rules, and the cached campaign rules file.")
        linkageFields = nil
        rulesEngine.replaceRules(with: [LaunchRule]())
        clearCachedRules()
    }

    /// The function does the following operations.
    /// 1). Clears the cached assets for the Campaign rules.
    /// 2). Remove the cached rules.json file.
    /// 3). Remove the rules URL from the Data store.
    private func clearCachedRules() {
        let campaignRulesCache = CampaignRulesCache()
        campaignRulesCache.deleteCachedAssets(fileManager: FileManager.default)
        guard let storedRulesUrl = state.getRulesUrlFromDataStore() else {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to remove cached rules. No rules url is found in Data store.")
            return
        }
        campaignRulesCache.deleteCachedRules(url: storedRulesUrl)
        state.removeRuleUrlFromDatastore()
    }

    /// Helper function to clean the CampaignFullscreenMessage object when the fullscreen message has been dismissed.
    private func cleanFullscreenMessage() {
        fullscreenMessage = nil
    }
}

// MARK: Functions to show IAMs
private extension Campaign {

    /// Triggers the alert IAM
    /// - Parameter consequence: the `RuleConsequence` containing an alert message
    func showAlertMessage(forConsequence consequence: RuleConsequence) {
        Log.debug(label: self.LOG_TAG, "\(#function) - Received a Rules Response content event containing an alert message.")
        guard let message = AlertMessage.createMessageObject(consequence: consequence, state: self.state, eventDispatcher: self.dispatchEvent(eventName:eventType:eventSource:eventData:)) else {
            Log.debug(label: self.LOG_TAG, "\(#function) - Unable to show Alert IAM for consequence '\(consequence.id)'. Message created was nil.")
            return
        }
        message.showMessage()
    }

    /// Triggers the fullscreen IAM
    /// - Parameter consequence: the `RuleConsequence` containing a fullscreen message
    func showFullScreenMessage(forConsequence consequence: RuleConsequence) {
        Log.debug(label: self.LOG_TAG, "\(#function) - Received a Rules Response content event containing a fullscreen message.")
        guard let message = CampaignFullscreenMessage.createMessageObject(consequence: consequence, state: self.state, eventDispatcher: self.dispatchEvent(eventName:eventType:eventSource:eventData:)) else {
            Log.debug(label: self.LOG_TAG, "\(#function) - Unable to show Fullscreen IAM for consequence '\(consequence.id)'. Message created was nil.")
            return
        }
        fullscreenMessage = message as? CampaignFullscreenMessage
        fullscreenMessage?.onFullscreenMessageDismissed = self.cleanFullscreenMessage
        fullscreenMessage?.showMessage()
    }

    /// Triggers the local notification IAM
    /// - Parameter consequence: the `RuleConsequence` containing a local notification message
    func showLocalNotification(forConsequence consequence: RuleConsequence) {
        Log.debug(label: self.LOG_TAG, "\(#function) - Received a Rules Response content event containing a local notification. Scheduling the received local notification.")
        guard let message = LocalNotificationMessage.createMessageObject(consequence: consequence, state: self.state, eventDispatcher: self.dispatchEvent(eventName:eventType:eventSource:eventData:)) else {
            Log.debug(label: self.LOG_TAG, "\(#function) - Unable to show Local notification for consequence '\(consequence.id)'. Message created was nil.")
            return
        }
        message.showMessage()
    }
}
