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
    private var privacyStatus: PrivacyStatus = .unknown

    // Campaign config
    private var campaignServer: String?
    private var campaignPkey: String?
    private var campaignMciasServer: String?
    private var campaignTimeout: TimeInterval?
    private var campaignPropertyId: String?
    private var campaignRegistrationDelay: TimeInterval?
    private var campaignRegistrationPaused: Bool?

    // Identity shared state
    private var ecid: String?

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
        self.campaignTimeout = configurationData[CampaignConstants.Configuration.CAMPAIGN_TIMEOUT] as? TimeInterval
        self.campaignPropertyId = configurationData[CampaignConstants.Configuration.PROPERTY_ID] as? String
        if let registrationDelayDays = configurationData[CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_DELAY_KEY] as? Int {
            self.campaignRegistrationDelay = TimeInterval(registrationDelayDays * CampaignConstants.Campaign.SECONDS_IN_A_DAY)
        }
        self.campaignRegistrationPaused = configurationData[CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_PAUSED_KEY] as? Bool
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

    func getExperienceCloudId() -> String? {
        return ecid
    }

    func getPrivacyStatus() -> PrivacyStatus {
        return privacyStatus
    }

    func getServer() -> String? {
        return campaignServer
    }

    func getPkey() -> String? {
        return campaignPkey
    }

    func getMciasServer() -> String? {
        return campaignMciasServer
    }

    func getTimeout() -> TimeInterval {
        return campaignTimeout ?? CampaignConstants.Campaign.DEFAULT_TIMEOUT
    }

    func getPropertyId() -> String? {
        return campaignPropertyId
    }

    func getRegistrationDelay() -> TimeInterval {
        return campaignRegistrationDelay ?? CampaignConstants.Campaign.DEFAULT_REGISTRATION_DELAY
    }

    func getRegistrationPausedStatus() -> Bool {
        return campaignRegistrationPaused ?? false
    }
}
