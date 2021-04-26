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
    var messageId: String {get set}
    var eventDispatcher: Campaign.EventDispatcher {get set}
    
    init(consequence: CampaignRuleConsequence)
    
    /// Creates a Campaign Message Object
    ///  - Parameters:
    ///     - consequence: CampaignRuleConsequence containing a Message-defining payload
    ///     - eventDispatcher: The Campaign event dispatcher
    ///  - Returns: A Campaign message object
    static func createMessageObject(consequence: CampaignRuleConsequence, eventDispatcher: Campaign.EventDispatcher) -> Message
    
    /// Creates an instance of the Message subclass and invokes method on the class to handle asset downloading, if it supports remote assets.
    ///  - Parameter consequence: CampaignRuleConsequence containing a Message-defining payload
    static func downloadRemoteAssets(consequence: CampaignRuleConsequence)
    
    /// Used by the Message subclass to display the message.
    func showMessage()
    
    /// Optional abstract method invoked to let the Message subclass handle asset downloading.
    func downloadAssets()
    
    /// Generates a dictionary with message data for a "message triggered" event and dispatches it using the Campaign event dispatcher.
    func triggered()
    
    /// Generates a dictionary with message data for a "message viewed" event and dispatches it using the Campaign event dispatcher.
    func viewed()
    
    /// Generates a dictionary with message data for a "message clicked" event and dispatches it using the Campaign event dispatcher.
    func clickedThrough()
    
    /// Generates a dictionary with message data for a "message triggered" event and dispatches it using the Campaign event dispatcher.
    /// This method also adds the click through URL to the data and attempts to open the URL, after decoding and expanding tokens in the URL.
    ///  - Parameter data: A dictionary containing message interaction data
    func clickedWithData(data: [String: String])
    
    /// Requests that the URLService opens the provided URL.
    func openUrl(url: URL)
    
    /// Expands the provided tokens in the given input string.
    ///  - Parameters:
    ///    - input: The input string containing tokens to be expanded
    ///    - tokens: A dictionary containing the strings to be used for token expansion.
    ///  - Returns: The input string containing expanded tokens. The method returns an unchanged input string if:
    ///     * Input string is nil or empty.
    ///     * Provided tokens dictionary is nil or empty.
    ///     * No key from the tokens dictionary is present in the input string.
    func expandTokens(input: String?, tokens: [String: String]?) -> String
    
    /// Invokes method in the Campaign instance to dispatch the provided message interaction event containing the interaction data.
    ///  - Parameter data: A dictionary containing message interaction data
    func callDispatchMessageInteraction(data: [String: String])
    
    /// Invokes method in the Campaign instance to dispatch the provided message info.
    ///  - Parameters:
    ///    - broadlogId: The message's broadlog ID.
    ///    - deliveryId: The message's delivery ID.
    ///    - action: The message's action type.
    func callDispatchMessageInfo(broadlogId: String, deliveryId: String, action: String)
    
    /// Determines whether a message should attempt to download assets for caching.
    ///  - Returns: A boolean indicating whether this should download assets.
    func shouldDownloadAssets() -> Bool
    
}
