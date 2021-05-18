/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
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

///The `CampaignRulesDownloader` is responsible for downloading rules from remote server/retrieve them from cache and loading them into `Rules Engine`.
struct CampaignRulesDownloader {

    ///Represents possible error during Rules downloading and saving.
    enum RulesDownloaderError: Error {
        case unableToCreateTempDirectory
        case unableToStoreDataInTempDirectory
    }

    private let LOG_TAG = "CampaignRulesDownloader"
    private let fileUnzipper: Unzipping
    private let rulesEngine: LaunchRulesEngine
    private let campaignMessageAssetsCache: CampaignMessageAssetsCache?
    let dispatchQueue: DispatchQueue?
    private let campaignRulesCache: CampaignRulesCache

    init(campaignRulesCache: CampaignRulesCache ,ruleEngine: LaunchRulesEngine, campaignMessageAssetsCache: CampaignMessageAssetsCache? = nil, dispatchQueue: DispatchQueue? = nil) {
        self.fileUnzipper = FileUnzipper()
        self.campaignRulesCache = campaignRulesCache
        self.rulesEngine = ruleEngine
        self.campaignMessageAssetsCache = campaignMessageAssetsCache
        self.dispatchQueue = dispatchQueue
    }

    ///Load the Cached Campaign rules into Rules engine.
    /// - Parameter rulesUrlString: The String representation of the URL used for downloading the rules.
    func loadRulesFromCache(rulesUrlString: String) {
        guard let cachedRules = campaignRulesCache.getCachedRules(rulesUrl: rulesUrlString) else {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to load Campaign cached rules for URL '\(rulesUrlString)'")
            return
        }

        if let _ = parseRulesDataAndLoadRules(data: cachedRules.cacheable) {
            Log.trace(label: LOG_TAG, "\(#function) - Successfully updated Campaign rules in Rules engine after reading from cache")
        } else {
            Log.warning(label: self.LOG_TAG, "\(#function) - Failed to parse cached rules.json file.")
        }
    }

    ///Download the Campaign rules from the passed `rulesUrl`, caches them and load them into the Rules engine.
    /// - Parameters:
    ///   - rulesUrl: The `URL` for downloading the Campaign rules.
    ///   - linkageFieldHeaders: The header with `linkageField` value
    ///   - state: Instance of `CampaignState` for storing rules download URL
    func loadRulesFromUrl(rulesUrl: URL, linkageFieldHeaders: [String: String]?, state: CampaignState) {
        /// 304 - Not Modified support
        var headers = [String: String]()
        if let cachedRules = campaignRulesCache.getCachedRules(rulesUrl: rulesUrl.absoluteString) {
            headers = cachedRules.notModifiedHeaders()
        }
        if let linkageFieldHeaders = linkageFieldHeaders {
            headers.merge(linkageFieldHeaders) { _, newValue in
                newValue
            }
        }

        let networkRequest = NetworkRequest(url: rulesUrl, httpMethod: .get, httpHeaders: headers)
        ServiceProvider.shared.networkService.connectAsync(networkRequest: networkRequest) { httpConnection in
            self.dispatchQueue?.async {
                if httpConnection.responseCode == 304 {
                    Log.debug(label: self.LOG_TAG, "\(#function) - Returning early without loading Campaign rules. Rules hasn't changed on server.")
                    return
                }

                guard let data = httpConnection.data else {
                    Log.debug(label: self.LOG_TAG, "\(#function) - Unable to load rules. Data in HTTP response is nil.")
                    return
                }
                // Store Zip file in temp directory for unzipping
                switch self.storeDataInTempDirectory(data: data) {
                case let .success(url):
                    // Unzip the rules.json and assets from the zip file in to the cache directory. Get the rules Data from the rules.json file.
                    guard let data = self.unzipRules(at: url) else {
                        Log.debug(label: self.LOG_TAG, "\(#function) - Failed to unzip downloaded rules.")
                        return
                    }
                    let cachedRules = CampaignCachedRules(cacheable: data,
                                                          lastModified: httpConnection.response?.allHeaderFields[NetworkServiceConstants.Headers.LAST_MODIFIED] as? String,
                                                          eTag: httpConnection.response?.allHeaderFields[NetworkServiceConstants.Headers.ETAG] as? String)

                    // Cache the rules, if fails, log message
                    let hasRulesCached = self.campaignRulesCache.setCachedRules(rulesUrl: rulesUrl.absoluteString, cachedRules: cachedRules)

                    if hasRulesCached {
                        state.updateRuleUrlInDataStore(url: url.absoluteString)
                    } else {
                        Log.warning(label: self.LOG_TAG, "Unable to cache Campaign rules")
                    }
                    if let rules = self.parseRulesDataAndLoadRules(data: data) {
                        Log.trace(label: self.LOG_TAG, "\(#function) - Successfully updated Campaign rules in Rules engine after downloading from remote")
                        self.downloadFullscreenIAMAssets(rules: rules)
                    } else {
                        Log.warning(label: self.LOG_TAG, "\(#function) - Failed to parse downloaded rules.json file.")
                    }
                    return
                case let .failure(error):
                    Log.warning(label: self.LOG_TAG, error.localizedDescription)
                    return
                }
            }
        }
    }

    ///Called after downloading the Campaign rules or reading cached rules. Loads the rules into rules engine.
    private func parseRulesDataAndLoadRules(data: Data) -> [LaunchRule]? {
        if let rules = JSONRulesParser.parse(data) {
            rulesEngine.replaceRules(with: rules)
            return rules
        }

        return nil
    }

    ///Downloads the Assets for fullscreen IAM
    private func downloadFullscreenIAMAssets(rules: [LaunchRule]) {
        guard let campaignMessageAssetsCache = campaignMessageAssetsCache else {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to cache Message Assets. CampaignMessageAssetsCache is nil.")
            return
        }
        var messageIdsWithAssets = [String]()
        for rule in rules {
            for consequence in rule.consequences {
                if consequence.hasAssetsToDownload() {
                    messageIdsWithAssets.append(consequence.id)
                    if let assetsUrl = consequence.createAssetUrlArray(), !assetsUrl.isEmpty {
                        campaignMessageAssetsCache.downloadAssetsForMessage(from: assetsUrl, messageId: consequence.id)
                    }
                }
            }
        }

        campaignMessageAssetsCache.clearCachedAssetsNotInList(filesToRetain: messageIdsWithAssets, pathRelativeToCacheDir: CampaignConstants.Campaign.MESSAGE_CACHE_FOLDER)
    }

    /// Stores the requested rules.zip data in a temp directory
    /// - Parameter data: The rules.zip as Data to be stored in the temp directory
    /// - Returns a `Result<URL, RulesDownloaderError>` with a `URL` to the zip file if successful or a `RulesDownloaderError` if a failure occurs
    private func storeDataInTempDirectory(data: Data) -> Result<URL, RulesDownloaderError> {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(CampaignConstants.RulesDownloaderConstants.RULES_TEMP_DIR)
        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return .failure(.unableToCreateTempDirectory)
        }
        let temporaryDirectoryWithZip = temporaryDirectory.appendingPathComponent(CampaignConstants.RulesDownloaderConstants.RULES_ZIP_FILE_NAME)
        guard let _ = try? data.write(to: temporaryDirectoryWithZip) else {
            return .failure(.unableToStoreDataInTempDirectory)
        }

        return .success(temporaryDirectoryWithZip)
    }

    /// Unzips the rules at the source url to a destination url and returns the rules as a dictionary
    /// - Parameter source: source URL for the zip file
    /// - Returns: The unzipped rules as a `Data`
    private func unzipRules(at source: URL) -> Data? {
        guard let cachedDir = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            Log.warning(label: LOG_TAG, "\(#function) - Unable to Unzip Campaign rules. Cache directory URL is nil.")
            return nil
        }
        let destination = cachedDir.appendingPathComponent(CampaignConstants.RulesDownloaderConstants.RULES_CACHE_DIRECTORY, isDirectory: true)
        let unzippedItems = fileUnzipper.unzipItem(at: source, to: destination)
        // Find the unzipped item rules.json
        guard let _ = unzippedItems.firstIndex(of: CampaignConstants.Campaign.Rules.JSON_FILE_NAME) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: destination.appendingPathComponent(CampaignConstants.Campaign.Rules.JSON_FILE_NAME))
            return data
        } catch {
            return nil
        }
    }
}

private extension RuleConsequence {

    ///Determines if the RuleConsequence have assets to download
    /// - Returns true if there are assets for downloading
    func hasAssetsToDownload() -> Bool {
        guard type == CampaignConstants.Campaign.IAM_CONSEQUENCE_TYPE else {
            return false
        }

        guard details[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_TEMPLATE] as? String == CampaignConstants.Campaign.MessagePayload.TEMPLATE_FULLSCREEN else {
            return false
        }

        guard details.keys.contains(CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_REMOTE_ASSETS) else {
            return false
        }

        return true
    }

    ///Parses the value for `assets` key in Rule Consequence and return an array of assets URL that need to be cached.
    /// - Returns An array of assets URL that need to be downloaded and cached
    func createAssetUrlArray() -> [String]? {
        guard let assetsArray = details[CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_REMOTE_ASSETS] as? [[String]]  else {
            return nil
        }
        var assetsToDownload: [String] = []
        for assets in assetsArray {
            for asset in assets {
                assetsToDownload.append(asset)
            }
        }
        return assetsToDownload
    }
}
