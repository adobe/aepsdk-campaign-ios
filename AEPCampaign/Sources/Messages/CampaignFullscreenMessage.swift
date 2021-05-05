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

class CampaignFullscreenMessage: Message {
    static let LOG_TAG = "FullscreenMessage"

    var eventDispatcher: Campaign.EventDispatcher?
    var messageId: String?

    private var state: CampaignState?
    private var html: String?
    private var htmlContent: String?
    private var assetsPath: String?
    private var extractedAssets: [[String]]?

    /// Campaign Fullscreen Message class initializer. It is accessed via the `createMessageObject` method.
    ///  - Parameters:
    ///    - consequence: CampaignRuleConsequence containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    private init(consequence: CampaignRuleConsequence, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) {
        self.messageId = consequence.id
        self.eventDispatcher = eventDispatcher
        self.state = state
        self.parseFullscreenMessagePayload(consequence: consequence)
    }

    /// Creates a Campaign Fullscreen Message object
    ///  - Parameters:
    ///    - consequence: CampaignRuleConsequence containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    ///  - Returns: A Message object or nil if the message object creation failed.
    @discardableResult static func createMessageObject(consequence: CampaignRuleConsequence?, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) -> Message? {
        guard let consequence = consequence else {
            Log.trace(label: LOG_TAG, "\(#function) - Cannot create a Fullscreen Message object, the consequence is nil.")
            return nil
        }
        let messageObject = CampaignFullscreenMessage(consequence: consequence, state: state, eventDispatcher: eventDispatcher)
        // html is required so no message object is returned if it is nil
        guard messageObject.html != nil else {
            return nil
        }
        return messageObject
    }

    func showMessage() {
        // state.fullscreenMessage = ServiceProvider.shared.uiService.createFullscreenMessage(payload: webViewHtml, listener: fullscreenMessageDelegate ?? self, isLocalImageUsed: false)
        // state.fullscreenMessage?.show()
    }

    // The Campaign Fullscreen Message class should download assets
    func shouldDownloadAssets() -> Bool {
        return true
    }

    func processMessageInteraction(query: [String: String]) {
        guard let id = query[CampaignConstants.Campaign.MessageData.TAG_ID], !id.isEmpty else {
            Log.debug(label: Self.LOG_TAG, "\(#function) - Cannot process message interaction, input query is nil or empty.")
            return
        }
        let strTokens = id.components(separatedBy: CampaignConstants.Campaign.MessageData.TAG_ID_DELIMITER)
        guard strTokens.count == CampaignConstants.Campaign.MessageData.ID_TOKENS_LEN else {
            Log.debug(label: Self.LOG_TAG, "\(#function) - Cannot process message interaction, input query contains an incorrect amount of id tokens.")
            return
        }
        let tagId = strTokens[2]
        switch tagId {
        case CampaignConstants.Campaign.MessageData.TAG_ID_BUTTON_1, // adbinapp://confirm/?id=h11901a,86f10d,3
             CampaignConstants.Campaign.MessageData.TAG_ID_BUTTON_2, // adbinapp://confirm/?id=h11901a,86f10d,4
             CampaignConstants.Campaign.MessageData.TAG_ID_BUTTON_X: // adbinapp://confirm/?id=h11901a,86f10d,5
            clickedWithData(data: query)
            viewed()
        default:
            Log.debug(label: Self.LOG_TAG, "\(#function) - Unsupported tag Id found in the id field in the given query: \(tagId)")
        }
    }

    /// Parses a `CampaignRuleConsequence` instance defining message payload for a `FullscreenMessage` object.
    /// Required fields:
    ///     * assetsPath: A `String` containing the location of cached fullscreen assets.
    ///     * html: A `String` containing html for this message
    /// Optional fields:
    ///     * assets: An array of `[String]` containing remote assets to prefetch and cache.
    ///  - Parameter consequence: CampaignRuleConsequence containing a Message-defining payload
    private func parseFullscreenMessagePayload(consequence: CampaignRuleConsequence) {
        guard let detail = consequence.detail, !detail.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The consequence details are nil or empty, dropping the fullscreen message.")
            return
        }
        // assets path is required
        guard let assetsPath = consequence.assetsPath, !assetsPath.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - Unable to create fullscreen message, provided assets path is missing/empty.")
            return
        }
        // html is required
        guard let html = detail[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_HTML] as? String, !html.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The html for a fullscreen message is required, dropping the notification.")
            return
        }
        self.html = html

        // assets are optional
        if let assetsArray = detail[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_REMOTE_ASSETS] as? [[String]], !assetsArray.isEmpty {
            for assets in assetsArray {
                extractAsset(assets: assets)
            }
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read assets for fullscreen message but found none. This is not a required field.")
        }
    }

    private func extractAsset(assets: [String]) {
        guard !assets.isEmpty else {
            Log.warning(label: Self.LOG_TAG, "\(#function) - There are no assets to extract.")
            return
        }
        var currentAsset: [String] = []
        for asset in assets where !asset.isEmpty {
            currentAsset.append(asset)
        }
        Log.trace(label: Self.LOG_TAG, "\(#function) - Adding \(currentAsset) to extracted assets.")
        extractedAssets?.append(currentAsset)
    }
}
