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

import AEPServices
import Foundation

/// Struct which represents an Campaign hit
struct CampaignHit: Codable {
    /// URL for the Campaign Hit
    let url: URL
    /// Payload of the Campaign hit
    let payload: String
    /// Timestamp of Campaign hit
    let timestamp: TimeInterval

    /// Determines the Http command based off the request payload
    /// - Returns: HttpCommandType.POST if the payload has content, otherwise HttpCommandType.GET
    func getHttpCommand() -> HttpMethod {
        return !payload.isEmpty ? HttpMethod.post : HttpMethod.get
    }
}
