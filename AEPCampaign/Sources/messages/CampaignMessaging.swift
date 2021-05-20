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

/// Defines Message Protocol for ACS In-App Messages.
protocol CampaignMessaging {
    var eventDispatcher: Campaign.EventDispatcher? {get set}
    var messageId: String? {get set}

    /// Implemented by the Message subclass to create a Campaign Message object.
    ///  - Parameters:
    ///    - consequence: `RuleConsequence` containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    ///  - Returns: A Campaign message object or nil if the message object creation failed.
    static func createMessageObject(consequence: RuleConsequence?, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) -> CampaignMessaging?

    /// Implemented by the Message subclass to display the message.
    func showMessage()

    /// Implemented by the Message subclass. This method determines whether a message should attempt to download assets for caching.
    ///  - Returns: A boolean indicating whether this should download assets.
    func shouldDownloadAssets() -> Bool
}

/// Defines default implementation for common or optional methods within the CampaignMessaging Protocol. These default methods *can* be overridden if desired.
extension CampaignMessaging {
    /// Expands the provided tokens in the given input string.
    ///  - Parameters:
    ///    - input: The input string containing tokens to be expanded
    ///    - tokens: A dictionary containing the strings to be used for token expansion.
    ///  - Returns: The input string containing expanded tokens. The method returns an unchanged input string if:
    ///     * Input string is nil or empty.
    ///     * Provided tokens dictionary is nil or empty.
    ///     * No key from the tokens dictionary is present in the input string.
    func expandTokens(input: String?, tokens: [String: String]?) -> String? {
        guard let input = input, !input.isEmpty else {
            Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot expand tokens, the input string is nil or empty.")
            return nil
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

    /// Generates a dictionary with message data for a "message triggered" event and dispatches it using the Campaign event dispatcher.
    func triggered() {
        guard let eventDispatcher = eventDispatcher else {
            Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot dispatch message triggered event, the event dispatcher is nil.")
            return
        }
        Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Dispatching message triggered event.")
        var messageData: [String: Any] = [:]
        messageData[CampaignConstants.ContextDataKeys.MESSAGE_ID] = messageId
        messageData[CampaignConstants.ContextDataKeys.MESSAGE_TRIGGERED] = "1"
        MessageInteractionTracker.dispatchMessageInteraction(data: messageData, eventDispatcher: eventDispatcher)
    }

    /// Generates a dictionary with message data for a "message viewed" event and dispatches it using the Campaign event dispatcher.
    func viewed() {
        guard let eventDispatcher = eventDispatcher else {
            Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot dispatch message viewed event, the event dispatcher is nil.")
            return
        }
        Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Dispatching message viewed event.")
        var messageData: [String: Any] = [:]
        messageData[CampaignConstants.ContextDataKeys.MESSAGE_ID] = messageId
        messageData[CampaignConstants.ContextDataKeys.MESSAGE_VIEWED] = "1"
        MessageInteractionTracker.dispatchMessageInteraction(data: messageData, eventDispatcher: eventDispatcher)
    }

    /// Generates a dictionary with message data for a "message clicked" event and dispatches it using the Campaign event dispatcher.
    func clickedThrough() {
        guard let eventDispatcher = eventDispatcher else {
            Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot dispatch message clicked event, the event dispatcher is nil.")
            return
        }
        Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Dispatching message clicked event.")
        var messageData: [String: Any] = [:]
        messageData[CampaignConstants.ContextDataKeys.MESSAGE_ID] = messageId
        messageData[CampaignConstants.ContextDataKeys.MESSAGE_CLICKED] = "1"
        MessageInteractionTracker.dispatchMessageInteraction(data: messageData, eventDispatcher: eventDispatcher)
    }

    /// Generates a dictionary with message data for a "message clicked" event and adds the click through URL to the data.
    /// The URL will also be opened after decoding and expanding any tokens present in the URL.
    /// The message data and click through URL are then dispatched using the Campaign event dispatcher.
    ///  - Parameters:
    ///    - data: A dictionary containing message interaction data
    func clickedWithData(data: [String: String]) {
        guard let eventDispatcher = eventDispatcher else {
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
                guard let messageId = messageId else {
                    Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot dispatch message clicked with data event, the message id is nil.")
                    return
                }
                let urlTokens = [CampaignConstants.Campaign.MESSAGE_ID_TOKEN: messageId]
                if let expandedUrl = expandTokens(input: url.absoluteString, tokens: urlTokens), !expandedUrl.isEmpty {
                    openUrl(url: URL(string: expandedUrl))
                    messageData[key] = expandedUrl
                }
            } else {
                messageData[key] = value
            }
        }

        Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Dispatching message clicked with data event.")
        messageData[CampaignConstants.ContextDataKeys.MESSAGE_ID] = messageId
        messageData[CampaignConstants.ContextDataKeys.MESSAGE_CLICKED] = "1"
        MessageInteractionTracker.dispatchMessageInteraction(data: messageData, eventDispatcher: eventDispatcher)
    }

    /// Optional method to let the Message subclass handle asset downloading.
    func downloadAssets() {}

    /// Optional method which creates an instance of the Message subclass and invokes a method within the class to handle asset downloading.
    func downloadRemoteAssets() {}
}
