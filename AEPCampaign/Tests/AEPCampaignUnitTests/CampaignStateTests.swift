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

import XCTest
import Foundation
import AEPServices
@testable import AEPCore
@testable import AEPCampaign

class CampaignStateTests: XCTestCase {

    var hitProcessor: MockHitProcessor!
    var dataQueue: MockDataQueue!
    var state: CampaignState!

    override func setUp() {
        dataQueue = MockDataQueue()
        hitProcessor = MockHitProcessor()
        state = CampaignState(hitQueue: PersistentHitQueue(dataQueue: dataQueue, processor: hitProcessor))
    }

    func testHitQueueNotNilOnCampaignStateInit() {
        XCTAssertNotNil(state.hitQueue)
    }

    func testUpdateWithConfigurationSharedState() {
        // setup
        let privacyStatus = PrivacyStatus.optedIn.rawValue
        let server = "campaign_server"
        let pkey = "pkey"
        let mciasServer = "campaign_rules/mcias"
        let timeout = 10
        let propertyId = "propertyId"
        let registrationDelay = 10
        let registrationPaused = true
        var configurationData = [String: Any]()
        configurationData[CampaignConstants.Configuration.CAMPAIGN_SERVER] = server
        configurationData[CampaignConstants.Configuration.CAMPAIGN_PKEY] = pkey
        configurationData[CampaignConstants.Configuration.CAMPAIGN_MCIAS] = mciasServer
        configurationData[CampaignConstants.Configuration.CAMPAIGN_TIMEOUT] = timeout
        configurationData[CampaignConstants.Configuration.PROPERTY_ID] = propertyId
        configurationData[CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_DELAY_KEY] = registrationDelay
        configurationData[CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_PAUSED_KEY] = registrationPaused
        configurationData[CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY] = privacyStatus
        // test
        var dataMap = [String: [String: Any]]()
        dataMap[CampaignConstants.Configuration.EXTENSION_NAME] = configurationData
        state.update(dataMap: dataMap)
        // verify
        XCTAssertEqual(state.privacyStatus, PrivacyStatus.optedIn)
        XCTAssertEqual(state.campaignServer, server)
        XCTAssertEqual(state.campaignPkey, pkey)
        XCTAssertEqual(state.campaignMciasServer, mciasServer)
        XCTAssertEqual(state.campaignTimeout, TimeInterval(timeout))
        XCTAssertEqual(state.campaignPropertyId, propertyId)
        XCTAssertEqual(state.campaignRegistrationDelay, TimeInterval(864000)) // 10 days in seconds
        XCTAssertEqual(state.campaignRegistrationPaused, registrationPaused)
    }

    func testUpdateWithConfigurationSharedStateVerifyDefaultValues() {
        // setup
        let server = "campaign_server"
        let pkey = "pkey"
        let mciasServer = "campaign_rules/mcias"
        let propertyId = "propertyId"
        var configurationData = [String: Any]()
        configurationData[CampaignConstants.Configuration.CAMPAIGN_SERVER] = server
        configurationData[CampaignConstants.Configuration.CAMPAIGN_PKEY] = pkey
        configurationData[CampaignConstants.Configuration.CAMPAIGN_MCIAS] = mciasServer
        configurationData[CampaignConstants.Configuration.PROPERTY_ID] = propertyId
        // test
        var dataMap = [String: [String: Any]]()
        dataMap[CampaignConstants.Configuration.EXTENSION_NAME] = configurationData
        state.update(dataMap: dataMap)
        // verify
        XCTAssertEqual(state.privacyStatus, PrivacyStatus.unknown) // default value is unknown
        XCTAssertEqual(state.campaignServer, server)
        XCTAssertEqual(state.campaignPkey, pkey)
        XCTAssertEqual(state.campaignMciasServer, mciasServer)
        XCTAssertEqual(state.campaignTimeout, TimeInterval(5)) // default value is 5 seconds
        XCTAssertEqual(state.campaignPropertyId, propertyId)
        XCTAssertEqual(state.campaignRegistrationDelay, TimeInterval(604800)) // default value is 7 days in seconds
        XCTAssertEqual(state.campaignRegistrationPaused, false) // default value is false
    }

    func testUpdateWithIdentitySharedState() {
        // setup
        let ecid = "ecid"
        var identityData = [String: Any]()
        identityData[CampaignConstants.Identity.EXPERIENCE_CLOUD_ID] = ecid
        // test
        var dataMap = [String: [String: Any]]()
        dataMap[CampaignConstants.Identity.EXTENSION_NAME] = identityData
        state.update(dataMap: dataMap)
        // verify
        XCTAssertEqual(state.ecid, ecid)
    }
}
