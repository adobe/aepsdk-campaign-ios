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
import AEPServices

extension URL {

    private static let LOG_TAG = "URL+Campaign"

    /// Builds the `URL` responsible for sending a Campaign profile request
    /// - Parameters:
    ///   - state: the Campaign state
    /// - Returns: A network request configured to send the Campaign profile request, nil if failed
    static func getCampaignProfileUrl(state: CampaignState) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        guard let server = state.getServer(), let pkey = state.getPkey(), let ecid = state.getExperienceCloudId(), !server.isEmpty, !pkey.isEmpty, !ecid.isEmpty else {
            Log.error(label: LOG_TAG, "The Campaign state did not contain the necessary configuration to build the profile url, returning nil.")
            return nil
        }
        // profile url: https://%s/rest/head/mobileAppV5/%s/subscriptions/%s
        components.host = server
        components.path = String(format: CampaignConstants.Campaign.PROFILE_URL_PATH, pkey, ecid)

        guard let url = components.url else {
            Log.error(label: LOG_TAG, "Building Campaign profile URL failed, returning nil.")
            return nil
        }
        return url
    }

    /// Creates a payload for a Campaign profile request
    /// - Parameters:
    ///   - state: the Campaign state
    ///   - data: additional profile data to be sent to campaign
    /// - Returns: A string containing the payload for the campaign request
    static func buildBody(state: CampaignState, data: [String: String]?) -> String? {
        guard let ecid = state.getExperienceCloudId() else {
            Log.error(label: Self.LOG_TAG, "The Campaign state did not contain an experience cloud id, returning nil.")
            return nil
        }

        var profileData = [String: String]()
        profileData.merge(data ?? [:], uniquingKeysWith: { _, new in new })
        profileData[CampaignConstants.Identity.EXPERIENCE_CLOUD_ID] = ecid
        profileData[CampaignConstants.Campaign.PUSH_PLATFORM] = "apns"

        let encoder = JSONEncoder()
        if let bodyJson = try? encoder.encode(profileData) {
            if let bodyJsonString = String(data: bodyJson, encoding: .utf8) {
                return bodyJsonString
            }
        }

        Log.error(label: Self.LOG_TAG, "Failed to create a json string payload, returning nil.")
        return nil
    }
}
