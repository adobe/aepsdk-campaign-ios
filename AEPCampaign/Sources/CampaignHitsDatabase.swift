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

import AEPCore
import AEPServices
import Foundation

class CampaignHitsDatabase {
    private let LOG_TAG = "CampaignDatabase"

    private var campaignState: CampaignState
    private var hitQueue: HitQueuing
    // Override for tests
    static var dataQueueService = ServiceProvider.shared.dataQueueService

    init?(state: CampaignState, processor: HitProcessing) {
        guard let dataQueue = CampaignHitsDatabase.dataQueueService.getDataQueue(label: CampaignConstants.EXTENSION_NAME) else {
            Log.error(label: self.LOG_TAG, "\(#function) - Failed to create data queue, Campaign Database could not be initialized")
            return nil
        }

        self.campaignState = state
        self.hitQueue = PersistentHitQueue(dataQueue: dataQueue, processor: processor)
    }

    /// Creates a Campaign Hit then queues the hit in the CampaignHitsDatabase.
    /// - Parameters:
    ///   - payload: the Campaign Hit payload
    ///   - timestamp: the Campaign Hit timestamp
    func queue(payload: String, timestamp: TimeInterval) {
        guard campaignState.getPrivacyStatus() != .optedOut else {
            Log.debug(label: self.LOG_TAG, "\(#function) - Dropping Campaign hit, privacy is opted-out.")
            return
        }

        guard let hitData = try? JSONEncoder().encode(CampaignHit(payload: payload, timestamp: timestamp)) else {
            Log.debug(label: self.LOG_TAG, "\(#function) - Dropping Campaign hit, failed to encode hit")
            return
        }

        let hit = DataEntity(uniqueIdentifier: UUID().uuidString, timestamp: Date(), data: hitData)
        hitQueue.queue(entity: hit)
        if campaignState.getPrivacyStatus() == .optedIn {
            hitQueue.beginProcessing()
        }
    }

    /// Returns the number of queued hits in the CampaignHitsDatabase
    func getQueueSize() -> Int {
        return hitQueue.count()
    }

    /// Updates the privacy status, resumes the queue processing when optin, and clears the queue when optout.
    /// The queue processing will be suspended when privacy is unknown.
    func updatePrivacyStatus() {
        switch campaignState.getPrivacyStatus() {
        case PrivacyStatus.optedIn:
            hitQueue.beginProcessing()
            break
        case PrivacyStatus.optedOut:
            reset()
            break
        default:
            hitQueue.suspend()
        }
    }

    private func reset() {
        hitQueue.suspend()
        hitQueue.clear()
    }
}
