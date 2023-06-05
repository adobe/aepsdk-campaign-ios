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

import AEPCore
import AEPServices
import Foundation

extension HitQueuing {
    /// Creates a Campaign Hit then queues the hit in the Campaign extension's `HitQueue`.
    /// - Parameters:
    ///   - url: the destination url of the `CampaignHit`
    ///   - payload: the `CampaignHit` payload
    ///   - timestamp: the `CampaignHit` timestamp
    ///   - privacyStatus: the current `PrivacyStatus`
    func queue(url: URL, payload: String, timestamp: TimeInterval, privacyStatus: PrivacyStatus) {
        handlePrivacyChange(status: privacyStatus)
        guard privacyStatus != .optedOut else {
            Log.debug(label: CampaignConstants.LOG_TAG, "CampaignHitQueuing: \(#function) - Dropping Campaign hit, privacy is opted-out.")
            return
        }

        guard let hitData = try? JSONEncoder().encode(CampaignHit(url: url, payload: payload, timestamp: timestamp)) else {
            Log.debug(label: CampaignConstants.LOG_TAG, "CampaignHitQueuing: \(#function) - Dropping Campaign hit, failed to encode hit")
            return
        }

        let hit = DataEntity(data: hitData)
        queue(entity: hit)
        Log.trace(label: CampaignConstants.LOG_TAG, "\(#function) - Campaign hit with URL '\(url.absoluteString)' and body '\(payload)' is queued.")
    }
}
