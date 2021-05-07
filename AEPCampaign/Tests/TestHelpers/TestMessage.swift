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
import AEPServices
@testable import AEPCore
@testable import AEPCampaign

/// TestMessage struct for testing the CampaignMessaging Protocol's default implementation
struct TestMessage: CampaignMessaging {
    var eventDispatcher: Campaign.EventDispatcher?
    var consequence: CampaignRuleConsequence?
    var messageId: String?
    var state: CampaignState?

    private init(consequence: CampaignRuleConsequence, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) {
        self.consequence = consequence
        self.messageId = consequence.id
        self.eventDispatcher = eventDispatcher
        self.state = state
    }

    static func createMessageObject(consequence: CampaignRuleConsequence?, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) -> CampaignMessaging? {
        guard let consequence = consequence else {
            return nil
        }
        return TestMessage(consequence: consequence, state: state, eventDispatcher: eventDispatcher)
    }

    func showMessage() {
        // no-op
    }

    func shouldDownloadAssets() -> Bool {
        // no-op
        return true
    }
}
