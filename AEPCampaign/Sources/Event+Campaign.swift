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
import Foundation

extension Event {
    /// Reads the triggered consequence from the Event
    var triggeredConsequence: [String: Any]? {
        return data?[CampaignConstants.EventDataKeys.RulesEngine.TRIGGERED_CONSEQUENCES] as? [String: Any]
    }

    /// Reads the broadlog id from the Event
    var broadlogId: String? {
        return data?[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID] as? String
    }

    /// Reads the delivery id from the Event
    var deliveryId: String? {
        return data?[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID] as? String
    }

    /// Reads the track action from the Event
    var action: String? {
        return data?[CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION] as? String
    }

    /// Base64 Encoded value of JSONEncoded Linkage fields.
    var linkageFields: String? {
        guard let linkageFieldsMap = data?[CampaignConstants.EventDataKeys.LINKAGE_FIELDS] as? [String: String], !linkageFieldsMap.isEmpty else {
            return nil
        }
        guard let serializedLinkageField = try? JSONEncoder().encode(linkageFieldsMap) else {
            return nil
        }

        return serializedLinkageField.base64EncodedString()
    }
}
