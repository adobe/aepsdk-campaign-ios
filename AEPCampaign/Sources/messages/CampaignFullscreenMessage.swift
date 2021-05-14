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

class CampaignFullscreenMessage: CampaignMessaging {
    private static let LOG_TAG = "FullscreenMessage"

    let fileManager = FileManager.default
    var eventDispatcher: Campaign.EventDispatcher?
    var messageId: String?

    public weak var fullscreenMessageDelegate: FullscreenMessageDelegate?

    private var state: CampaignState?
    private var html: String?
    private var extractedAssets: [[String]]?
    private var isUsingLocalImage = false
    private var fullscreenMessage: FullscreenPresentable?

    #if DEBUG
        // var for unit testing
        var htmlPayload: String?
    #endif

    /// CampaignFullscreenMessage class initializer. It is accessed via the `createMessageObject` method.
    ///  - Parameters:
    ///    - consequence: `RuleConsequence` containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    private init(consequence: RuleConsequence, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) {
        self.messageId = consequence.id
        self.eventDispatcher = eventDispatcher
        self.state = state
        self.isUsingLocalImage = false
        self.extractedAssets = []
        self.parseFullscreenMessagePayload(consequence: consequence)
    }

    /// Creates a `CampaignFullscreenMessage` object
    ///  - Parameters:
    ///    - consequence: `RuleConsequence` containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    ///  - Returns: A Message object or nil if the message object creation failed.
    static func createMessageObject(consequence: RuleConsequence?, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) -> CampaignMessaging? {
        guard let consequence = consequence else {
            Log.trace(label: LOG_TAG, "\(#function) - Cannot create a Fullscreen Message object, the consequence is nil.")
            return nil
        }
        let fullscreenMessage = CampaignFullscreenMessage(consequence: consequence, state: state, eventDispatcher: eventDispatcher)
        // html is required so no message object is returned if it is nil
        guard fullscreenMessage.html != nil else {
            return nil
        }
        return fullscreenMessage
    }

    /// Instantiates  a new `CampaignFullscreenMessage` object then calls `show()` to display the message.
    /// This method reads the html content from the cached html within the rules cache and generates the expanded html by
    /// replacing assets URLs with cached references, before calling the method to display the message.
    func showMessage() {
        guard let html = html, let htmlContent = getHtmlFromCache(fileName: html), !htmlContent.isEmpty else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Failed to read html content from the Campaign rules cache.")
            return
        }

        // use assets if not empty
        var finalHtml = ""
        if let extractedAssets = extractedAssets, !extractedAssets.isEmpty {
            finalHtml = generateExpandedHtml(sourceHtml: htmlContent)
        } else {
            finalHtml = htmlContent
        }
        self.htmlPayload = finalHtml
        self.fullscreenMessage = ServiceProvider.shared.uiService.createFullscreenMessage(payload: finalHtml, listener: self.fullscreenMessageDelegate ?? self, isLocalImageUsed: false)
        self.fullscreenMessage?.show()
    }

    /// Returns true as the Campaign Fullscreen Message class should download assets
    func shouldDownloadAssets() -> Bool {
        return true
    }

    /// Attempts to handle fullscreen message interaction by inspecting the id field on the clicked message.
    ///  - Parameter query: A `[String: String]` dictionary containing message interaction details
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

    /// Parses a `CampaignRuleConsequence` instance defining message payload for a `CampaignFullscreenMessage` object.
    /// Required fields:
    ///     * html: A `String` containing html for this message
    /// Optional fields:
    ///     * assets: An array of `[String]`s containing remote assets to prefetch and cache.
    ///  - Parameter consequence: `RuleConsequence` containing a Message-defining payload
    private func parseFullscreenMessagePayload(consequence: RuleConsequence) {
        guard !consequence.details.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The consequence details are nil or empty, dropping the fullscreen message.")
            return
        }
        let detail = consequence.details

        // html is required
        guard let html = detail[CampaignConstants.EventDataKeys.RulesEngine.Detail.HTML] as? String, !html.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The html filename for a fullscreen message is required, dropping the notification.")
            return
        }
        self.html = html

        // assets are optional
        if let assetsArray = detail[CampaignConstants.EventDataKeys.RulesEngine.Detail.REMOTE_ASSETS] as? [[String]], !assetsArray.isEmpty {
            for assets in assetsArray {
                extractAsset(assets: assets)
            }
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read assets for fullscreen message but found none. This is not a required field.")
        }
    }

    /// Extract assets for the HTML message.
    ///  - Parameter assets: An array of `Strings` containing assets specific for this `CampaignFullscreenMessage`.
    private func extractAsset(assets: [String]) {
        guard !assets.isEmpty else {
            Log.debug(label: Self.LOG_TAG, "\(#function) - There are no assets to extract.")
            return
        }
        var currentAsset: [String] = []
        for asset in assets where !asset.isEmpty {
            currentAsset.append(asset)
        }
        Log.trace(label: Self.LOG_TAG, "\(#function) - Adding \(currentAsset) to extracted assets.")
        extractedAssets?.append(currentAsset)
    }

    /// Replace the image urls in the HTML with cached URIs for those images. If no cache URIs are found, then use a local image asset, if it has been
    /// provided in the assets.
    ///  - Parameter sourceHtml: A `String` containing the HTML payload of the fullscreen message.
    ///  - Returns: The HTML `String` with image tokens replaced with cached URIs, if available.
    private func generateExpandedHtml(sourceHtml: String) -> String {
        // if we have no extracted assets, return the source html unchanged
        guard let extractedAssets = extractedAssets, !extractedAssets.isEmpty else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Not generating expanded html, extracted assets is nil or empty.")
            return sourceHtml
        }
        var imageTokens: [String: String] = [:]
        // the first element in asset is a url
        // the remaining elements in the are urls or file paths to assets that should replace that asset in the resulting html if they are already cached
        for asset in extractedAssets {
            // the url to replace
            let assetUrl = asset[0]

            // use getAssetReplacement to get the string that should
            // replace the given asset
            let assetValue = getAssetReplacement(assetArray: asset) ?? ""
            if assetValue.isEmpty {
                continue // no replacement, move on
            } else {
                // save it
                imageTokens[assetUrl] = assetValue
            }
        }

        // actually replace the asset
        return expandTokens(input: sourceHtml, tokens: imageTokens) ?? ""
    }

    /// Returns the remote or local URL to use in asset replacement.
    ///  - Parameter assetArray: An array of `Strings`containing the an asset url and the cached remote or local assets that
    ///   should be used to replace them.
    ///  - Returns: A `String` containing either a cached URI, or a local asset name, or nil if neither is present.
    private func getAssetReplacement(assetArray: [String]) -> String? {
        guard !assetArray.isEmpty else { // edge case
            Log.debug(label: Self.LOG_TAG, "\(#function) - Cannot replace assets, the assets array is empty.")
            return nil
        }

        // first prioritize remote urls that are cached
        for asset in assetArray.dropFirst() {
            if let messageId = messageId, let url = URL(string: asset), url.scheme == CampaignConstants.Campaign.Scheme.HTTPS {
                guard var cacheDir = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
                    Log.debug(label: Self.LOG_TAG, "\(#function) - Cannot replace assets, the message cache directory does not exist.")
                    return nil
                }
                cacheDir.appendPathComponent("\(CampaignConstants.Campaign.MESSAGE_CACHE_FOLDER)/\(messageId)/\(url.absoluteString.alphanumeric)")
                Log.trace(label: Self.LOG_TAG, "\(#function) - Will replace \(assetArray[0]) with cached remote assets from \(asset).")
                return cacheDir.path
            }
        }

        // then fallback to local urls
        for asset in assetArray.dropFirst() {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Replaced assets using local file \(asset).")
            self.isUsingLocalImage = true
            return asset
        }
        return nil
    }

    /// Returns the html as a `String` from the download rule.zip's assets directory (/campaignrules/assets/)
    ///  - Parameter fileName: A `String` containing the HTML filename.
    ///  - Returns: A `String` containing the HTML file contents for this message.
    private func getHtmlFromCache(fileName: String) -> String? {
        guard let cacheDir = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return nil
        }
        let htmlInAssets = cacheDir.appendingPathComponent(CampaignConstants.RulesDownloaderConstants.RULES_CACHE_DIRECTORY).appendingPathComponent(CampaignConstants.RulesDownloaderConstants.ASSETS_DIR_NAME).appendingPathComponent(fileName)
        guard let htmlFile = try? String(contentsOf: htmlInAssets) else {
            return nil
        }
        return htmlFile
    }
}
