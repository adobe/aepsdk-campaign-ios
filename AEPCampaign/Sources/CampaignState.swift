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
    private(set) var dataStore: NamedCollectionDataStore

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

    private(set) var namedCollectionDataStore = NamedCollectionDataStore(name: CampaignConstants.DATASTORE_NAME)

    /// Creates a new `CampaignState`.
    init(hitQueue: HitQueuing) {
        self.hitQueue = hitQueue
        self.dataStore = NamedCollectionDataStore(name: CampaignConstants.DATASTORE_NAME)
        // initialize defaults
        self.campaignTimeout = TimeInterval(CampaignConstants.Campaign.DEFAULT_TIMEOUT)
        self.campaignRegistrationDelay = CampaignConstants.Campaign.DEFAULT_REGISTRATION_DELAY
        self.campaignRegistrationPaused = false
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

    /// Determines if this `CampaignState` is valid for sending a registration request to Campaign.
    ///- Returns true if the CampaignState is valid else return false
    private func canRegisterWithCurrentState() -> Bool {
        if let ecid = ecid, let campaignServer = campaignServer, let campaignPkey = campaignPkey, !ecid.isEmpty, !campaignServer.isEmpty, !campaignPkey.isEmpty, privacyStatus == PrivacyStatus.optedIn {
            return true
        }
        return false
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

    ///Determines if the registration request should send to Campaign. Returns true, if the ecid has changed or number of days passed since the last registration is greater than registrationDelay in obtained in Configuration shared state.
    func shouldSendRegistrationRequest(eventTimeStamp: TimeInterval) -> Bool {
        guard let ecid = ecid, let registrationDelay = campaignRegistrationDelay else {
            Log.debug(label: LOG_TAG, "\(#function) - Returning false. Required Campaign Configuration is not present.")
            return false
        }

        guard !(campaignRegistrationPaused ?? false) else {
            Log.debug(label: LOG_TAG, "\(#function) - Returning false, Registration requests are paused.")
            return false
        }

        if namedCollectionDataStore.getString(key: CampaignConstants.Campaign.Datastore.ECID_KEY, fallback: "") != ecid {
            Log.debug(label: LOG_TAG, "\(#function) - The current ecid '\(ecid)' is new, sending the registration request.")
            namedCollectionDataStore.set(key: CampaignConstants.Campaign.Datastore.ECID_KEY, value: ecid)
            return true
        }

        let retrievedTimeStamp = namedCollectionDataStore.getLong(key: CampaignConstants.Campaign.Datastore.REGISTRATION_TIMESTAMP_KEY) ?? Int64(CampaignConstants.Campaign.DEFAULT_TIMESTAMP_VALUE)

        if eventTimeStamp - TimeInterval(retrievedTimeStamp) >= registrationDelay {
            Log.debug(label: LOG_TAG, "\(#function) - Registration delay of '\(registrationDelay)' seconds has elapsed. Sending the Campaign registration request.")
            return true
        }

        Log.debug(label: LOG_TAG, "\(#function) - The registration request will not be sent because the registration delay of \(registrationDelay) seconds has not elapsed.")
        return false
    }

    ///Process the network requests
    /// - Parameters:
    ///    - url: The request URL
    ///    - payload: The request payload
    ///    - event:The `Event` that triggered the network request
    func processRequest(url: URL, payload: String, event: Event) {
        // check if this request is a registration request by checking for the presence of a payload and if it is a registration request, determine if it should be sent.
        if !payload.isEmpty { //Registration request
            guard shouldSendRegistrationRequest(eventTimeStamp: event.timestamp.timeIntervalSince1970) else {
                Log.warning(label: LOG_TAG, "\(#function) - Unable to process request.")
                return
            }
        }

        hitQueue.queue(url: url, payload: payload, timestamp: event.timestamp.timeIntervalSince1970, privacyStatus: privacyStatus)
    }

    /// Invoked by the Campaign extension each time we successfully send a Campaign network request.
    /// If the request was a Campaign registration request, the current timestamp and ecid will be stored in the Campaign Datastore.
    /// - Parameters:
    ///   - hit: The `CampaignHit` which was successfully sent
    func updateDatastoreWithSuccessfulRegistrationInfo(hit: CampaignHit) {
        Log.trace(label: LOG_TAG, "\(#function) - Persisting timestamp \(hit.timestamp) in Campaign Datastore.")
        dataStore.set(key: CampaignConstants.Campaign.Datastore.REGISTRATION_TIMESTAMP_KEY, value: hit.timestamp)
        if let ecid = self.ecid, !ecid.isEmpty {
            Log.trace(label: LOG_TAG, "\(#function) - Persisting ECID \(ecid) in Campaign Datastore.")
            dataStore.set(key: CampaignConstants.Campaign.Datastore.ECID_KEY, value: ecid)
    }
}
