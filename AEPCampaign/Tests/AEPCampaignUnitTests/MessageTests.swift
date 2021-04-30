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

class MessageTests: XCTestCase {
    var state: CampaignState!
    var hitProcessor: MockHitProcessor!
    var dataQueue: MockDataQueue!
    var mockNetworkService: MockNetworking? {
        return ServiceProvider.shared.networkService as? MockNetworking
    }
    var messageObject: Message!

    override func setUp() {
        dataQueue = MockDataQueue()
        hitProcessor = MockHitProcessor()
        state = CampaignState()
        addStateData()
        let details = ["content": "some content"] as [String: Any]
        let localNotificationConsequence = CampaignRuleConsequence(id: "20761932", type: "iam", assetsPath: nil, detailDictionary: details)
        messageObject = LocalNotificationMessage.createMessageObject(consequence: localNotificationConsequence, state: state, eventDispatcher: { _, _, _, _ in })
    }

    func addStateData(customConfig: [String: Any]? = nil) {
        var configurationData = [String: Any]()
        configurationData[CampaignConstants.Configuration.CAMPAIGN_SERVER] = "campaign-server"
        configurationData[CampaignConstants.Configuration.CAMPAIGN_PKEY] = "pkey"
        configurationData[CampaignConstants.Configuration.PROPERTY_ID] = "propertyId"
        configurationData[CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY] = PrivacyStatus.unknown.rawValue
        configurationData.merge(customConfig ?? [:]) { _, new in new }
        var identityData = [String: Any]()
        identityData[CampaignConstants.Identity.EXPERIENCE_CLOUD_ID] = "ecid"
        var dataMap = [String: [String: Any]]()
        dataMap[CampaignConstants.Configuration.EXTENSION_NAME] = configurationData
        dataMap[CampaignConstants.Identity.EXTENSION_NAME] = identityData
        state.update(dataMap: dataMap)
    }

    func testExpandTokens() {
        // setup
        let testString = "1,2,3,4,5,6,7"
        let tokens = ["2": "two", "4": "four", "7": "seven"]
        // test
        let expandedString = messageObject.expandTokens(input: testString, tokens: tokens)
        // verify
        XCTAssertEqual("1,two,3,four,5,6,seven", expandedString)
    }

    func testExpandTokensWhenTokensAreNil() {
        // setup
        let testString = "1,2,3,4,5,6,7"
        // test
        let expandedString = messageObject.expandTokens(input: testString, tokens: nil)
        // verify
        XCTAssertEqual(testString, expandedString)
    }

    func testExpandTokensWhenInputStringIsNil() {
        // setup
        let tokens = ["2": "two", "4": "four", "7": "seven"]
        // test
        let expandedString = messageObject.expandTokens(input: nil, tokens: tokens)
        // verify
        XCTAssertNil(expandedString)
    }
}
