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

    var eventDispatcher: Campaign.EventDispatcher?
    var messageId: String?

    private let campaignFullscreenMessageDelegate = CampaignFullscreenMessageDelegate()

    private var state: CampaignState?
    private var html: String?
    private var assetsPath: String?
    private var extractedAssets: [[String]]?
    private var isUsingLocalImage: Bool
    private var fullscreenMessage: FullscreenPresentable?
    private var messageAssetsDownloader: MessageAssetsDownloader?

    /// Campaign Fullscreen Message class initializer. It is accessed via the `createMessageObject` method.
    ///  - Parameters:
    ///    - consequence: CampaignRuleConsequence containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    private init(consequence: CampaignRuleConsequence, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) {
        self.messageId = consequence.id
        self.eventDispatcher = eventDispatcher
        self.state = state
        self.isUsingLocalImage = false
        self.parseFullscreenMessagePayload(consequence: consequence)
    }

    /// Creates a Campaign Fullscreen Message object
    ///  - Parameters:
    ///    - consequence: CampaignRuleConsequence containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    ///  - Returns: A Message object or nil if the message object creation failed.
    @discardableResult static func createMessageObject(consequence: CampaignRuleConsequence?, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) -> CampaignMessaging? {
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

    /// Creates and shows a new Campaign Fullscreen Message object.
    /// This method reads the html content from the cached html at assetsPath and generates the expanded html by
    /// replacing assets URLs with cached references, before calling the method to display the message.
    func showMessage() {
        guard let assetsPath = assetsPath, let html = html else {
            Log.debug(label: Self.LOG_TAG, "\(#function) - Cannot show the fullscreen message, assets path or html is nil.")
            return
        }
        let htmlLocation = assetsPath + CampaignConstants.Campaign.PATH_SEPARATOR + html
        guard let htmlContent = readHtmlFromFile(location: htmlLocation) else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Failed to read html content from the cache location: \(htmlLocation)")
            return
        }

        // use assets if not empty
        var finalHtml = ""
        if let extractedAssets = extractedAssets, !extractedAssets.isEmpty {
            finalHtml = generateExpandedHtml(sourceHtml: htmlContent)
        } else {
            finalHtml = htmlContent
        }
        
        fullscreenMessage = ServiceProvider.shared.uiService.createFullscreenMessage(payload: finalHtml, listener: campaignFullscreenMessageDelegate, isLocalImageUsed: isUsingLocalImage)
        fullscreenMessage?.show()
    }

    // Returns true as the Campaign Fullscreen Message class should download assets
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

    func downloadAssets() {
        guard let extractedAssets = extractedAssets, !extractedAssets.isEmpty else {
            Log.debug(label: Self.LOG_TAG, "\(#function) - No assets to be downloaded.")
            return
        }

        for currentAssetArray in extractedAssets {
            let currentAssetArrayCount = currentAssetArray.count

            // no strings in this asset, skip this entry
            if currentAssetArrayCount <= 0 {
                continue
            }

            let messageId = self.messageId ?? ""
            self.messageAssetsDownloader = MessageAssetsDownloader(assets: currentAssetArray, messageId: messageId)
            Log.debug(label: Self.LOG_TAG, "\(#function) - Downloading assets for message id: \(messageId).")
            messageAssetsDownloader?.downloadAssetCollection()
        }
    }

    /// Parses a `CampaignRuleConsequence` instance defining message payload for a `FullscreenMessage` object.
    /// Required fields:
    ///     * assetsPath: A `String` containing the location of cached fullscreen assets.
    ///     * html: A `String` containing html for this message
    /// Optional fields:
    ///     * assets: An array of `[String]` containing remote assets to prefetch and cache.
    ///  - Parameter consequence: CampaignRuleConsequence containing a Message-defining payload
    func parseFullscreenMessagePayload(consequence: CampaignRuleConsequence) {
        guard let detail = consequence.detail, !detail.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The consequence details are nil or empty, dropping the fullscreen message.")
            return
        }
        // assets path is required
        guard let assetsPath = consequence.assetsPath, !assetsPath.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - Unable to create fullscreen message, provided assets path is missing/empty.")
            return
        }
        self.assetsPath = assetsPath

        // html is required
        guard let html = detail[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_HTML] as? String, !html.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The html filename for a fullscreen message is required, dropping the notification.")
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

    func extractAsset(assets: [String]) {
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

    private func readHtmlFromFile(location: String) -> String? {
        // FOR TESTING ONLY, use final implementation from rules downloader
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cachesDirectoryUrl = urls[0]
        let fileUrl = cachesDirectoryUrl.appendingPathComponent("adbdownloadcache/assets/test.html")
        let filePath = fileUrl.path

        guard let data = fileManager.contents(atPath: filePath) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func generateExpandedHtml(sourceHtml: String) -> String {
        // if we have no extracted assets, return the source html unchanged
        guard let extractedAssets = extractedAssets, !extractedAssets.isEmpty else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Not generating expanded html, extracted assets is nil or empty.")
            return sourceHtml
        }
        var imageTokens: [String: String] = [:]
        // the first element in assets is a url
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

    func getAssetReplacement(assetArray: [String]) -> String? {
        guard !assetArray.isEmpty else { // edge case
            Log.debug(label: Self.LOG_TAG, "\(#function) - Cannot replace assets, the assets array is empty.")
            return nil
        }

        // first prioritize remote urls that are cached
        for asset in assetArray {
            if let url = URL(string: asset) {
                if MessageAssetsDownloader.isAssetDownloadable(url: url) {
                    let cacheService = ServiceProvider.shared.cacheService
                    let messageId = self.messageId ?? ""
                    let cacheEntry = cacheService.get(cacheName: CampaignConstants.Campaign.MESSAGE_CACHE_FOLDER + CampaignConstants.Campaign.PATH_SEPARATOR + messageId, key: asset)
                    if let data = cacheEntry?.data {
                        Log.debug(label: Self.LOG_TAG, "\(#function) - Replaced assets using cached assets.")
                        return String(decoding: data, as: UTF8.self)
                    }
                }
            }
        }

        // then fallback to local urls
        for asset in assetArray {
            if let url = URL(string: asset) {
                if MessageAssetsDownloader.isAssetDownloadable(url: url) {
                    Log.debug(label: Self.LOG_TAG, "\(#function) - Replaced assets using local url.")
                    self.isUsingLocalImage = true
                    return asset
                }
            }
        }
        return nil
    }
}
