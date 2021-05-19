///*
// Copyright 2021 Adobe. All rights reserved.
// This file is licensed to you under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License. You may obtain a copy
// of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
// OF ANY KIND, either express or implied. See the License for the specific language
// governing permissions and limitations under the License.
// */
//
import Foundation
import AEPServices

///A Type that downloads and caches the Assets(images) associated with a Fullscreen IAM.
struct CampaignMessageAssetsCache {

    private let LOG_PREFIX = "CampaignMessageAssetsCache"
    let fileManager = FileManager.default
    let dispatchQueue: DispatchQueue

    ///Download and Caches the Assets for a given messageId.
    ///- Parameters:
    ///  - urls: An array of URL of Assets
    ///  - messageId: The id of the message
    func downloadAssetsForMessage(from urls: [String], messageId: String) {
        Log.trace(label: LOG_PREFIX, "\(#function) - Will attempt to download assets for Message (\(messageId) from URLs: \(urls)")
        var assetsToRetain: [URL] = []
        for urlString in urls {
            guard let url = URL(string: urlString) else {
                continue
            }
            assetsToRetain.append(url)
        }
        let assetToRetainAlphaNumeric = assetsToRetain.map { url in
            url.absoluteString.alphanumeric
        }
        clearCachedAssetsForMessagesNotInList(filesToRetain: assetToRetainAlphaNumeric, pathRelativeToCacheDir: "\(CampaignConstants.Campaign.MESSAGE_CACHE_FOLDER)/\(messageId)")
        downloadAssets(urls: assetsToRetain, messageId: messageId)
    }

    ///Iterate over the URL's array and triggers the download Network request
    private func downloadAssets(urls: [URL], messageId: String) {
        let networking = ServiceProvider.shared.networkService
        for url in urls {
            let networkRequest = NetworkRequest(url: url, httpMethod: .get)
            networking.connectAsync(networkRequest: networkRequest) { httpConnection in
                self.dispatchQueue.async {
                    guard httpConnection.responseCode == 200, let data = httpConnection.data else {
                        Log.debug(label: self.LOG_PREFIX, "\(#function) - Failed to download Asset from URL: \(url)")
                        return
                    }
                    self.cacheAssetData(data, forKey: url, messageId: messageId)
                }
            }
        }
    }

    ///Caches the downloaded `Data` for Assets
    /// - Parameters:
    ///  - data: The downloaded `Data`
    ///  - forKey: The Asset download URL. Used to name cache folder.
    ///  - messageId: The id of message
    private func cacheAssetData(_ data: Data, forKey url: URL, messageId: String) {
        guard let path = createDirectoryIfNeeded(messageId: messageId) else {
            Log.debug(label: LOG_PREFIX, "Unable to cache Asset for URL: (\(url). Unable to create cache directory.")
            return
        }
        let cachedAssetPathString = "\(path)/\(url.absoluteString.alphanumeric)"
        guard let cachedAssetPath = URL(string: cachedAssetPathString) else {
            Log.debug(label: LOG_PREFIX, "Unable to cache Asset for URL: (\(url). Unable to create cache file Path.")
            return
        }

        do {
            try data.write(to: cachedAssetPath)
            Log.trace(label: LOG_PREFIX, "Successfully cached Asset for URL: (\(url)")
        } catch {
            Log.debug(label: LOG_PREFIX, "Unable to cache Asset for URL: (\(url). Unable to write data to file path.")
        }
    }

    ///Deletes all the files in `pathRelativeToCacheDir` that are not present in `filesToRetain` array. This is used to delete the cached assets that are no longer required.
    /// - Parameters:
    ///   - filesToRetain: An array of file names that have to retain.
    ///   - pathRelativeToCacheDir: The path of cache directory relative to `Library/Cache`
    func clearCachedAssetsForMessagesNotInList(filesToRetain: [String], pathRelativeToCacheDir: String) {
        Log.trace(label: LOG_PREFIX, "\(#function) - Attempt to delete the Non required cached assets from directory \(pathRelativeToCacheDir)")
        guard var cacheDir = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return
        }
        cacheDir.appendPathComponent(pathRelativeToCacheDir)
        guard let cachedFiles = try? fileManager.contentsOfDirectory(atPath: cacheDir.absoluteString) else {
            return
        }
        let assetsToDelete = cachedFiles.filter { cachedFile in
            !filesToRetain.contains(cachedFile)
        }

        // MARK: Delete non required cached files for the message
        assetsToDelete.forEach { fileName in
            try? fileManager.removeItem(atPath: "\(cacheDir.absoluteString)/\(fileName)")
            Log.debug(label: LOG_PREFIX, "\(#function) - Deleted the non required cached asset at path: \(cacheDir.absoluteString)/\(fileName)")
        }
    }

    /// Creates the directory to store the cache if it does not exist
    /// - Parameters messageId: The message Id
    /// - Returns the Path to the Message Cache folder, Returns nil if cache folder does not exist and unable to create
    private func createDirectoryIfNeeded(messageId: String) -> String? {
        guard let cacheUrl = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            Log.debug(label: LOG_PREFIX, "\(#function) - \(#function) - Failed to retrieve cache directory URL.")
            return nil
        }
        let pathString = "\(cacheUrl.absoluteString)/\(CampaignConstants.Campaign.MESSAGE_CACHE_FOLDER)/\(messageId)"
        guard !fileManager.fileExists(atPath: pathString) else {
            Log.trace(label: LOG_PREFIX, "\(#function) - Assets cache directory for message \(messageId) already exists.")
            return pathString
        }

        Log.trace(label: LOG_PREFIX, "\(#function) - Attempting to create Assets cache directory for message \(messageId) at path: \(pathString)")
        do {
            try fileManager.createDirectory(atPath: pathString, withIntermediateDirectories: true, attributes: nil)
            return pathString
        } catch {
            Log.trace(label: LOG_PREFIX, "\(#function) - Error in creating Assets cache directory for message \(messageId) at path: \(pathString).")
            return nil
        }
    }
}

extension String {

    ///Removes non alphanumeric character from `String`
    var alphanumeric: String {
        return components(separatedBy: CharacterSet.alphanumerics.inverted).joined().lowercased()
    }
}
