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

import XCTest
import Foundation
import AEPServices
@testable import AEPCore
@testable import AEPCampaign

class LocalNotificationMessageTests: XCTestCase {

    var state: CampaignState!
    var hitProcessor: MockHitProcessor!
    var dataQueue: MockDataQueue!
    var responseCallbackArgs = [CampaignHit]()
    var mockNetworkService: MockNetworking? {
        return ServiceProvider.shared.networkService as? MockNetworking
    }

    override func setUp() {
        dataQueue = MockDataQueue()
        hitProcessor = MockHitProcessor()
        state = CampaignState(hitQueue: PersistentHitQueue(dataQueue: dataQueue, processor: hitProcessor))
        addStateData()
    }

    func testCreateLocalNotificationMessageWithValidConsequence() {
        let localDetailDictionary = ["title": "ACS Local Notification Test", "detail": "This is some demo text 🌊☄️", "wait": TimeInterval(3), "userData": ["broadlogId": "h1cbf60",
                                                                                                                                                          "deliveryId": "154767c"], "template": "local"] as [String: Any]
        let localConsequence = ["id": UUID().uuidString, "type": "iam", "assetsPath": nil, "detailDictionary":
        let consequence = CampaignRuleConsequence(id: <#T##String#>, type: <#T##String#>, assetsPath: <#T##String?#>, detailDictionary: <#T##[String : Any]?#>)
    }
}
