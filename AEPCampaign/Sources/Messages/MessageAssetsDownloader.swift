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

class MessageAssetsDownloader {
    static let LOG_TAG = "MessageAssetsDownloader"

    private let assets: [String]
    private let cacheSubdirectory: String

    init(assets: [String], messageId: String) {
        self.assets = assets
        self.cacheSubdirectory = CampaignConstants.Campaign.MESSAGE_CACHE_FOLDER + CampaignConstants.Campaign.PATH_SEPARATOR + messageId
    }

    static func isAssetDownloadable(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Log.error(label: Self.LOG_TAG, "\(#function) - Unable to get url components from \(url.absoluteString).")
            return false
        }
        if let scheme = components.scheme {
            return scheme == "https"
        }
        return false
    }

    func downloadAssetCollection() {
        // Clear out old assets to avoid accumulating over time
        // NOTE: only one FullScreenMessage can be active at a time and *only* those have assets
        var assetsToRetain: [String] = []
        for asset in assets {
            if let url = URL(string: asset) {
                // only retain downloadable assets
                if Self.isAssetDownloadable(url: url) {
                    assetsToRetain.append(asset)
                }
            }
        }
//        remote_file_manager_->DeleteCachedDataNotInList(cache_sub_dir_, assets_to_retain);
//
//        // Download new assets
//        for (auto& asset : assets_to_retain) {
//            remote_file_manager_->GetFileAsync(cache_sub_dir_,
//            asset, [ = ](const Expected<std::shared_ptr<RemoteFileInterface>>& result) {
//                if (static_cast<bool>(result)) {
//                    auto file = result.ConstValue();
//                    Log::Debug(CampaignConstants::LOG_PREFIX, "Downloaded asset and cached at %s",
//                               file->ToUri());
//                }
//            })
//        }
    }
}
