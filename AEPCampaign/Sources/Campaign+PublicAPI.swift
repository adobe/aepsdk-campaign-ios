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

/// Defines the public interface for the Campaign extension
@objc
public extension Campaign {
    private static let LOG_TAG = "Campaign"

    /// Sets the Campaign linkage fields (CRM IDs) in the mobile SDK to be used for downloading personalized messages from Campaign.
    /// The set linkage fields are stored as base64 encoded JSON string in memory and they are sent in a custom HTTP header 'X-InApp-Auth'
    /// in all future Campaign rules download requests until `resetLinkageFields` is invoked. These in-memory variables are also
    /// lost in the wake of an Application crash event or upon graceful Application termination or when the privacy status is updated to OPT_OUT.
    /// This method clears cached rules from previous download before triggering a rules download request to the configured Campaign server.
    /// If the current SDK privacy status is not OPT_IN, no rules download occurs.
    /// - Parameters linkageFields: The linkage fields key value pairs.
    @objc (setLinkageFields:)
    static func setLinkageFields(_ linkageFields: [String: String]) {
        guard !linkageFields.isEmpty else {
            Log.debug(label: LOG_TAG, "\(#function) - Unable to set the linkage fields. The passed in linkage fields dictionary is empty.")
            return
        }

        let data  = [CampaignConstants.EventDataKeys.LINKAGE_FIELDS: linkageFields]
        let event = Event(name: "SetLinkageFields", type: EventType.campaign, source: EventSource.requestIdentity, data: data)
        MobileCore.dispatch(event: event)
    }

    /// Clears previously stored linkage fields in the mobile SDK and triggers a Campaign rules download request to the configured Campaign server.
    /// This method unregisters any previously registered rules with the Event Hub and clears cached rules from the previous download.
    /// If the current SDK privacy status is not `OPT_IN`, no rules download occurs.
    @objc (resetLinkageFields)
    static func resetLinkageFields() {
        let event = Event(name: "ResetLinkageFields", type: EventType.campaign, source: EventSource.requestReset, data: nil)
        MobileCore.dispatch(event: event)
    }
}
