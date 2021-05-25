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
@testable import AEPServices
@testable import AEPCore
@testable import AEPCampaign

class MessagingImplementationTests: XCTestCase {
    var state: CampaignState!
    var hitProcessor: MockHitProcessor!
    var dataQueue: MockDataQueue!
    var mockUrlService: MockUrlService? {
        return ServiceProvider.shared.urlService as? MockUrlService
    }
    var messageObject: CampaignMessaging!
    var dispatchedEvents: [Event] = []
    var consequence: RuleConsequence!

    override func setUp() {
        ServiceProvider.shared.urlService = MockUrlService()
        dataQueue = MockDataQueue()
        hitProcessor = MockHitProcessor()
        state = CampaignState()
        addStateData()
        let details = ["content": "some content"] as [String: Any]
        consequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        messageObject = TestMessage.createMessageObject(consequence: consequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        })
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

    // MARK: expandTokens tests
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

    // MARK: openUrl tests
    func testOpenURL() {
        // setup
        let url = URL(string: "https://testurl.com")
        // test
        messageObject.openUrl(url: url)
        // verify
        XCTAssertEqual(mockUrlService?.openedUrl, url?.absoluteString)
    }

    func testOpenNilURL() {
        // test
        messageObject.openUrl(url: nil)
        // verify
        XCTAssertEqual(mockUrlService?.openedUrl, "")
    }

    // MARK: message interaction tests
    func testMessageViewed() {
        // test
        messageObject.viewed()
        // verify
        let messageViewedEvent = dispatchedEvents.first
        let messageParameters = ["event": messageViewedEvent as Any, "actionType": "viewed", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testMessageClicked() {
        // test
        messageObject.clickedThrough()
        // verify
        let messageClickedEvent = dispatchedEvents.first
        let messageParameters = ["event": messageClickedEvent as Any, "actionType": "clicked", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testMessageTriggered() {
        // test
        messageObject.triggered()
        // verify
        let messageTriggeredEvent = dispatchedEvents.first
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testMessageClickedWithDataHasUrl() {
        // test
        messageObject.clickedWithData(data: ["url": "https://testUrlWithId=messageId"])
        // verify
        let messageClickedEvent = dispatchedEvents.first
        let messageParameters = ["event": messageClickedEvent as Any, "actionType": "clicked", "size": 3] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testMessageClickedWithDataHasGenericData() {
        // test
        messageObject.clickedWithData(data: ["key": "value", "key2": "value2"])
        // verify
        let messageClickedEvent = dispatchedEvents.first
        let messageParameters = ["event": messageClickedEvent as Any, "actionType": "clicked", "size": 4] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testMessageClickedWithDataEmptyData() {
        // test
        messageObject.clickedWithData(data: [:])
        // verify
        let messageClickedEvent = dispatchedEvents.first
        let messageParameters = ["event": messageClickedEvent as Any, "actionType": "clicked", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }
}
