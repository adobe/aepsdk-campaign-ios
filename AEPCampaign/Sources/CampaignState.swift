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

class CampaignState {
    private let LOG_TAG = "CampaignState"

    // Privacy status
    private(set) var privacyStatus: PrivacyStatus = .unknown

    // Campaign config
    private(set) var campaignServer: String?
    private(set) var campaignPkey: String?
    private(set) var campaignMciasServer: String?
    private(set) var campaignTimeout: TimeInterval?
    private(set) var campaignPropertyId: String?
    private(set) var campaignRegistrationDelay: TimeInterval?
    private(set) var campaignRegistrationPaused: Bool?

    // Identity shared state
    private(set) var ecid: String?

    // Campaign Persistent HitQueue
    private(set) var hitQueue: HitQueuing

    /// Creates a new `CampaignState`.
    init(hitQueue: HitQueuing) {
        self.hitQueue = hitQueue
    }

    /// Takes the shared states map and updates the data within the Campaign State.
    /// - Parameter dataMap: The map contains the shared state data required by the Campaign Extension.
    func update(dataMap: [String: [String: Any]?]) {
        for key in dataMap.keys {
            guard let sharedState = dataMap[key] else {
                continue
            }
            switch key {
            case CampaignConstants.Configuration.EXTENSION_NAME:
                extractConfigurationInfo(from: sharedState ?? [:])
            case CampaignConstants.Identity.EXTENSION_NAME:
                extractIdentityInfo(from: sharedState)
            default:
                break
            }
        }
    }

    /// Extracts the configuration data from the provided shared state data.
    /// - Parameter configurationData the data map from `Configuration` shared state.
    private func extractConfigurationInfo(from configurationData: [String: Any]) {
        self.privacyStatus = PrivacyStatus.init(rawValue: configurationData[CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY] as? PrivacyStatus.RawValue ?? PrivacyStatus.unknown.rawValue) ?? .unknown
        self.campaignServer = configurationData[CampaignConstants.Configuration.CAMPAIGN_SERVER] as? String
        self.campaignPkey = configurationData[CampaignConstants.Configuration.CAMPAIGN_PKEY] as? String
        self.campaignMciasServer = configurationData[CampaignConstants.Configuration.CAMPAIGN_MCIAS] as? String
        self.campaignTimeout = TimeInterval(configurationData[CampaignConstants.Configuration.CAMPAIGN_TIMEOUT] as? Int ?? CampaignConstants.Campaign.DEFAULT_TIMEOUT)
        self.campaignPropertyId = configurationData[CampaignConstants.Configuration.PROPERTY_ID] as? String
        if let registrationDelayDays = configurationData[CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_DELAY_KEY] as? Int {
            self.campaignRegistrationDelay = TimeInterval(registrationDelayDays * CampaignConstants.Campaign.SECONDS_IN_A_DAY)
        } else {
            self.campaignRegistrationDelay = CampaignConstants.Campaign.DEFAULT_REGISTRATION_DELAY
        }
        self.campaignRegistrationPaused = configurationData[CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_PAUSED_KEY] as? Bool ?? false

        // update the hitQueue with the latest privacy status
        hitQueue.handlePrivacyChange(status: self.privacyStatus)
    }

    /// Extracts the identity data from the provided shared state data.
    /// - Parameter identityData the data map from `Identity` shared state.
    private func extractIdentityInfo(from identityData: [String: Any]?) {
        guard let identityData = identityData else {
            Log.trace(label: LOG_TAG, "\(#function) - Failed to extract identity data (event data was nil).")
            return
        }
        self.ecid = identityData[CampaignConstants.Identity.EXPERIENCE_CLOUD_ID] as? String
    }
    
    ///Determines if this `CampaignState` is valid for sending message track request to Campaign.
    ///- Returns true if the CampaignState is valid else return false
    func canSendTrackInfoWithCurrentState() -> Bool {
        guard privacyStatus == .optedIn else {
            Log.debug(label: LOG_TAG, "\(#function) Unable to send message track info to Campaign. Privacy status is not OptedIn.")
            return false
        }
        
        guard let ecid = ecid, !ecid.isEmpty else {
            Log.debug(label: LOG_TAG, "\(#function) Unable to send message track info to Campaign. ECID is invalid.")
            return false
        }
        
        guard let campaignServer = campaignServer, !campaignServer.isEmpty else {
            Log.debug(label: LOG_TAG, "\(#function) Unable to send message track info to Campaign. Campaign server value is invalid.")
            return false
        }
        
        return true
    }
}
