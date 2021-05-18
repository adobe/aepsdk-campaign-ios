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

    /// Builds the `URL` responsible for sending a Campaign registration request
    /// - Parameters:
    ///    - campaignServer: Campaign server
    ///    - pkey: Campaign pkey
    ///    - ecid: The experience cloud id of user
    /// - Returns: A `URL` destination to send the Campaign registration request, nil if failed
    static func getCampaignProfileUrl(campaignServer: String?, pkey: String?, ecid: String?) -> URL? {
        guard let campaignServer = campaignServer, let pkey = pkey, let ecid = ecid else {
            return nil
        }
        // profile url: https://campaignServer/rest/head/mobileAppV5/pkey/subscriptions/ecid
        var components = URLComponents()
        components.scheme = "https"
        components.host = campaignServer
        components.path = String(format: CampaignConstants.Campaign.PROFILE_URL_PATH, pkey, ecid)

        return components.url
    }

    /// Builds the `URL` responsible for sending a Campaign rules download request to MCIAS
    /// - Parameters:
    ///    - mciasServer: Campaign Mcias server
    ///    - campaignServer: Campaign server
    ///    - propertyId: Campaign property id
    ///    - ecid: The experience cloud id of user
    /// - Returns: A`URL` destination to send the Campaign rules download request, nil if failed
    static func getRulesDownloadUrl(mciasServer: String?, campaignServer: String?, propertyId: String?, ecid: String?) -> URL? {
        guard let mciasServer = mciasServer, let campaignServer = campaignServer, let propertyId = propertyId, let ecid = ecid else {
            return nil
        }
        // rules url: https://mciasServer/campaignServer/propertyId/ecid/rules.zip
        var components = URLComponents()
        components.scheme = "https"
        let mciasHost = String(mciasServer.split(separator: "/").first ?? "")
        components.host = mciasHost
        components.path = String(format: CampaignConstants.Campaign.RULES_DOWNLOAD_PATH, campaignServer, propertyId, ecid)

        return components.url
    }

    /// Creates a payload for a Campaign registration request
    /// - Parameters:
    ///   - ecid: The experience cloud id of the user
    ///   - data: additional profile data to be sent to Campaign
    /// - Returns: A string containing the payload for the Campaign request
    static func buildBody(ecid: String?, data: [String: String]?) -> String? {
        guard let ecid = ecid else {
            return nil
        }

        var profileData = [String: String]()
        profileData.merge(data ?? [:]) { _, new in new }
        profileData[CampaignConstants.Campaign.PROFILE_REQUEST_EXPERIENCE_CLOUD_ID] = ecid
        profileData[CampaignConstants.Campaign.PROFILE_REQUEST_PUSH_PLATFORM] = "apns"

        let encoder = JSONEncoder()
        if let bodyJson = try? encoder.encode(profileData) {
            if let bodyJsonString = String(data: bodyJson, encoding: .utf8) {
                return bodyJsonString
            }
        }

        Log.error(label: Self.LOG_TAG, "Failed to create a json string payload, returning nil.")
        return nil
    }

    /// Builds the URL for Message tracking
    /// - Parameters:
    ///    - host: Campaign server
    ///    - broadLogId: The BroadLogId for Message
    ///    - deliveryId: The DeliveryId for Message
    ///    - action: The action value for type of interaction(impression, click and open)
    ///    - ecid: The experience cloud id of user
    static func buildTrackingUrl(
        host: String,
        broadLogId: String,
        deliveryId: String,
        action: String,
        ecid: String) -> URL? {

        guard !host.isEmpty, !broadLogId.isEmpty, !deliveryId.isEmpty, !action.isEmpty, !ecid.isEmpty else {
            return nil
        }

        var urlComponent = URLComponents()
        urlComponent.scheme = "https"
        urlComponent.host = host
        urlComponent.path = "/r"
        urlComponent.queryItems = [
            URLQueryItem(name: "id", value: "\(broadLogId),\(deliveryId),\(action)"),
            URLQueryItem(name: "mcId", value: ecid)
        ]

        return urlComponent.url
    }
}
