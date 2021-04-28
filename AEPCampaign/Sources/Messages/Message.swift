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

protocol Message {
    static var eventDispatcher: Campaign.EventDispatcher? {get set}
    static var state: CampaignState? {get set}
    var messageId: String {get set}

    /// Message class initializer
    ///  - Parameters:
    ///    - consequence: CampaignRuleConsequence containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    init(consequence: CampaignRuleConsequence, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher)

    /// Used by the Message subclass to display the message.
    func showMessage()

    /// Generates a dictionary with message data for a "message triggered" event and dispatches it using the Campaign event dispatcher.
    /// - Parameter deliveryId: the delivery id of the triggered message
    func triggered(deliveryId: String)

    /// Determines whether a message should attempt to download assets for caching.
    ///  - Returns: A boolean indicating whether this should download assets.
    func shouldDownloadAssets() -> Bool
}

/// Define default implementation for common or optional methods within the Message Protocol
extension Message {
    /// Creates a Campaign Message Object
    ///  - Parameter consequence: CampaignRuleConsequence containing a Message-defining payload
    ///  - Returns: A Campaign message object
    @discardableResult static func createMessageObject(consequence: CampaignRuleConsequence) -> Message? {
        guard let eventDispatcher = self.eventDispatcher else {
            Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot create message object, the event dispatcher is nil.")
            return nil
        }
        guard let state = self.state else {
            Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot create message object, the Campaign State is nil.")
            return nil
        }

        let messageObject = self.init(consequence: consequence, state: state, eventDispatcher: eventDispatcher)
        if messageObject.shouldDownloadAssets() {
            messageObject.downloadRemoteAssets(consequence: consequence)
        }
        return messageObject
    }

    /// Creates an instance of the Message subclass and invokes a method within the class to handle asset downloading if it supports remote assets.
    ///  - Parameter consequence: CampaignRuleConsequence containing a Message-defining payload
    func downloadRemoteAssets(consequence: CampaignRuleConsequence) {
        Self.createMessageObject(consequence: consequence)
    }

    /// Expands the provided tokens in the given input string.
    ///  - Parameters:
    ///    - input: The input string containing tokens to be expanded
    ///    - tokens: A dictionary containing the strings to be used for token expansion.
    ///  - Returns: The input string containing expanded tokens. The method returns an unchanged input string if:
    ///     * Input string is nil or empty.
    ///     * Provided tokens dictionary is nil or empty.
    ///     * No key from the tokens dictionary is present in the input string.
    func expandTokens(input: String?, tokens: [String: String]?) -> String {
        guard let input = input, !input.isEmpty else {
            Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot expand tokens, the input string is nil or empty.")
            return ""
        }
        guard let tokens = tokens, !tokens.isEmpty else {
            Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot expand tokens, the token dictionary is nil or empty.")
            return input
        }
        var returnString = input
        for (key, value) in tokens {
            returnString = returnString.replacingOccurrences(of: key, with: value)
        }
        return returnString
    }

    /// Requests that the URLService opens the provided URL.
    /// - Parameter url: the URL to be opened
    func openUrl(url: URL?) {
        guard let url = url else {
            Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot open URL, the given URL is nil.")
            return
        }
        Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Opening URL: \(url).")
        ServiceProvider.shared.urlService.openUrl(url)
    }

    /// Generates a dictionary with message data for a "message viewed" event and dispatches it using the Campaign event dispatcher.
    /// - Parameter deliveryId: the delivery id of the viewed message
    func viewed(deliveryId: String) {
        guard let eventDispatcher = Self.eventDispatcher else {
            Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot dispatch message viewed event, the event dispatcher is nil.")
            return
        }
        Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Dispatching message viewed event.")
        MessageInteractionTracker.dispatchMessageEvent(action: CampaignConstants.ContextDataKeys.MESSAGE_VIEWED, deliveryId: deliveryId, eventDispatcher: eventDispatcher)
    }

    /// Generates a dictionary with message data for a "message clicked" event and dispatches it using the Campaign event dispatcher.
    /// - Parameter deliveryId: the delivery id of the clicked message
    func clickedThrough(deliveryId: String) {
        guard let eventDispatcher = Self.eventDispatcher else {
            Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot dispatch message clicked event, the event dispatcher is nil.")
            return
        }
        Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Dispatching message clicked event.")
        MessageInteractionTracker.dispatchMessageEvent(action: CampaignConstants.ContextDataKeys.MESSAGE_CLICKED, deliveryId: deliveryId, eventDispatcher: eventDispatcher)
    }

    /// Generates a dictionary with message data for a "message triggered" event and dispatches it using the Campaign event dispatcher.
    /// This method also adds the click through URL to the data and attempts to open the URL, after decoding and expanding tokens in the URL.
    ///  - Parameters:
    ///    - deliveryId: the delivery id of the clicked message
    ///    - data: A dictionary containing message interaction data
    func clickedWithData(deliveryId: String, data: [String: String]) {
        guard let eventDispatcher = Self.eventDispatcher else {
            Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot dispatch message clicked with data event, the event dispatcher is nil.")
            return
        }

        var messageData: [String: Any] = [:]
        for (key, value) in data {
            if key == CampaignConstants.Campaign.MessagePayload.INTERACTION_URL {
                guard let url = URL(string: value) else {
                    Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Failed to create URL from \(value).")
                    return
                }
                let urlTokens = [CampaignConstants.Campaign.MESSAGE_ID_TOKEN: messageId]
                let expandedUrl = expandTokens(input: url.absoluteString, tokens: urlTokens)
                openUrl(url: URL(string: expandedUrl))
                messageData[key] = expandedUrl
            } else {
                messageData[key] = value
            }
        }

        Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Dispatching message clicked with data event.")
        messageData[CampaignConstants.Campaign.MESSAGE_ID_TOKEN] = messageId
        messageData[CampaignConstants.ContextDataKeys.MESSAGE_CLICKED] = "1"
        eventDispatcher("InternalGenericDataEvent", EventType.genericData, EventSource.os, messageData)
    }

    /// Optional method to let the Message subclass handle asset downloading.
    func downloadAssets() {}
}
