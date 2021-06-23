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
import AEPServices

struct CampaignRulesCache {
    private let LOG_TAG = "CampaignRulesCache"
    private let cache = Cache(name: CampaignConstants.RulesDownloaderConstants.RULES_CACHE_NAME)

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
    ///    - rulesUrl: The rules url string to be used for building the key
    ///    - cachedRules: The `CachedRules` to be set in cache
    /// - Returns: A boolean indicating if caching succeeded or not
    func setCachedRules(rulesUrl: String, cachedRules: CampaignCachedRules) -> Bool {
        do {
            let data = try JSONEncoder().encode(cachedRules)
            let cacheEntry = CacheEntry(data: data, expiry: .never, metadata: nil)
            try cache.set(key: buildCacheKey(rulesUrl: rulesUrl), entry: cacheEntry)
            return true
        } catch {
            Log.warning(label: LOG_TAG, "\(#function) - Error thrown during caching Campaign rules.")
            return false
        }
    }

    /// Gets the cached rules for the given rulesUrl
    /// - Parameter rulesUrl: The rules url as a string to be used to get the right cached rules
    /// - Returns: The `CachedRules` for the given rulesUrl
    func getCachedRules(rulesUrl: String) -> CampaignCachedRules? {
        guard let cachedEntry = cache.get(key: buildCacheKey(rulesUrl: rulesUrl)) else {
            return nil
        }
        return try? JSONDecoder().decode(CampaignCachedRules.self, from: cachedEntry.data)
    }

    /// Deletes the cached campaign rules.json from Cache Service.
    /// - Parameter url: The rules URL which is used as key to cache rules.json
    func deleteCachedRules(url: String) {
        let cacheKey = buildCacheKey(rulesUrl: url)
        do {
            try cache.remove(key: cacheKey)
        } catch {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to remove the cached campaign rule.json from CacheService")
        }
    }

    /// Deletes the cached campaign assets.
    func deleteCachedAssets(fileManager: FileManager) {
        guard var cacheDir = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return
        }

        cacheDir.appendPathComponent(CampaignConstants.RulesDownloaderConstants.RULES_CACHE_FOLDER)
        do {
            try fileManager.removeItem(at: cacheDir)
            Log.trace(label: LOG_TAG, "\(#function) - Successfully deleted the \(CampaignConstants.RulesDownloaderConstants.RULES_CACHE_FOLDER) folder")
        } catch {
            Log.debug(label: LOG_TAG, "\(#function) - Error in deleting the \(CampaignConstants.RulesDownloaderConstants.RULES_CACHE_FOLDER) folder")
        }
    }
}
