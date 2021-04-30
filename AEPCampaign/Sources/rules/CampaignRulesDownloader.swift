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
    private let cache: Cache
    private let rulesEngine: LaunchRulesEngine

    init(fileUnzipper: Unzipping, ruleEngine: LaunchRulesEngine) {
        self.fileUnzipper = fileUnzipper
        cache = Cache(name: CampaignConstants.RulesDownloaderConstants.RULES_CACHE_NAME)
        self.rulesEngine = ruleEngine
    }

    ///Load the Cached Campaign rules into Rules engine.
    /// - Parameters:
    ///   - rulesUrlString: The String representation of the URL used for downloading the rules.
    func loadRulesFromCache(rulesUrlString: String) {        
        guard let cachedRules = getCachedRules(rulesUrl: rulesUrlString) else {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to load Campaign cached rules for URL (\(rulesUrlString)")
            return
        }

        loadRulesIntoRulesEngine(data: cachedRules.cacheable)
    }

    ///Download the Campaign rules from the passed `rulesUrl`, caches them and load them into the Rules engine.
    /// - Parameters:
    ///   - rulesUrl: The `URL` for downloading the Campaign rules.
    func loadRulesFromUrl(rulesUrl: URL) {
        /// 304 - Not Modified support
        var headers = [String: String]()
        if let cachedRules = getCachedRules(rulesUrl: rulesUrl.absoluteString) {
            headers = cachedRules.notModifiedHeaders()
        }

        let networkRequest = NetworkRequest(url: rulesUrl, httpMethod: .get, httpHeaders: headers)
        ServiceProvider.shared.networkService.connectAsync(networkRequest: networkRequest) { httpConnection in
            if httpConnection.responseCode == 304 {
                return
            }

            guard let data = httpConnection.data else {
                return
            }
            // Store Zip file in temp directory for unzipping
            switch self.storeDataInTempDirectory(data: data) {
            case let .success(url):
                // Unzip the rules.json and assets from the zip file in to the cache directory. Get the rules dict from the rules.json file.
                guard let data = self.unzipRules(at: url) else {
                    return
                }
                let cachedRules = CampaignCachedRules(cacheable: data,
                                                      lastModified: httpConnection.response?.allHeaderFields[NetworkServiceConstants.Headers.LAST_MODIFIED] as? String,
                                                      eTag: httpConnection.response?.allHeaderFields[NetworkServiceConstants.Headers.ETAG] as? String)
                // Cache the rules, if fails, log message
                if !self.setCachedRules(rulesUrl: rulesUrl.absoluteString, cachedRules: cachedRules) {
                    Log.warning(label: LOG_TAG, "Unable to cache Campaign rules")
                }
                loadRulesIntoRulesEngine(data: data)
                return
            case let .failure(error):
                Log.warning(label: LOG_TAG, error.localizedDescription)
                return
            }
        }
    }

    ///Replaces the existing rules with the new Collection of rules in Rules Engine.
    private func loadRulesIntoRulesEngine(data: Data) {
        if let rules = JSONRulesParser.parse(data) {
            rulesEngine.replaceRules(with: rules)
        }
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
    /// - Returns: The unzipped rules as a dictionary
    private func unzipRules(at source: URL) -> Data? {
        guard let cachedDir = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return nil
        }
        let destination = cachedDir.appendingPathComponent(CampaignConstants.RulesDownloaderConstants.RULES_CACHE_DIRECTORY, isDirectory: true)
        let unzippedItems = fileUnzipper.unzipItem(at: source, to: destination)
        // Find the unzipped item rules.json
        guard let _ = unzippedItems.firstIndex(of: "rules.json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: destination.appendingPathComponent("rules.json"))
            return data
        } catch {
            return nil
        }
    }

    /// Builds the cache key from the rules url and the rules cache prefix
    /// - Parameter rulesUrl: The rules url
    /// - Returns: The built cache key for the rules
    private func buildCacheKey(rulesUrl: String) -> String {
        let utf8RulesUrl = rulesUrl.data(using: .utf8)
        guard let base64RulesUrl = utf8RulesUrl?.base64EncodedString() else {
            return CampaignConstants.RulesDownloaderConstants.Keys.RULES_CACHE_PREFIX + rulesUrl
        }

        return CampaignConstants.RulesDownloaderConstants.Keys.RULES_CACHE_PREFIX + base64RulesUrl
    }

    /// Caches the given rules
    /// - Parameters:
    ///     - rulesUrl: The rules url string to be used for building the key
    ///     - cachedRules: The `CachedRules` to be set in cache
    /// - Returns: A boolean indicating if caching succeeded or not
    private func setCachedRules(rulesUrl: String, cachedRules: CampaignCachedRules) -> Bool {
        do {
            let data = try JSONEncoder().encode(cachedRules)
            let cacheEntry = CacheEntry(data: data, expiry: .never, metadata: nil)
            try cache.set(key: buildCacheKey(rulesUrl: rulesUrl), entry: cacheEntry)
            return true
        } catch {
            // Handle Error
            return false
        }
    }

    /// Gets the cached rules for the given rulesUrl
    /// - Parameter rulesUrl: The rules url as a string to be used to get the right cached rules
    /// - Returns: The `CachedRules` for the given rulesUrl
    private func getCachedRules(rulesUrl: String) -> CampaignCachedRules? {
        guard let cachedEntry = cache.get(key: buildCacheKey(rulesUrl: rulesUrl)) else {
            return nil
        }
        return try? JSONDecoder().decode(CampaignCachedRules.self, from: cachedEntry.data)
    }
}
