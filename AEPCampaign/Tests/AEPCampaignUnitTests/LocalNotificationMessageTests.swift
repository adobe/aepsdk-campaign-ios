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
    var dispatchedEvents: [Event] = []

    override func setUp() {
        dataQueue = MockDataQueue()
        hitProcessor = MockHitProcessor()
        state = CampaignState()
        addStateData()
    }

    func addStateData(customConfig: [String: Any]? = nil) {
        var configurationData = [String: Any]()
        configurationData[CampaignConstants.Configuration.CAMPAIGN_SERVER] = "campaign-server"
        configurationData[CampaignConstants.Configuration.CAMPAIGN_PKEY] = "pkey"
        configurationData[CampaignConstants.Configuration.PROPERTY_ID] = "propertyId"
        configurationData[CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY] = PrivacyStatus.optedIn.rawValue
        configurationData.merge(customConfig ?? [:]) { _, new in new }
        var identityData = [String: Any]()
        identityData[CampaignConstants.Identity.EXPERIENCE_CLOUD_ID] = "ecid"
        var dataMap = [String: [String: Any]]()
        dataMap[CampaignConstants.Configuration.EXTENSION_NAME] = configurationData
        dataMap[CampaignConstants.Identity.EXTENSION_NAME] = identityData
        state.update(dataMap: dataMap)
    }

    // MARK: local notification message creation tests
    func testCreateLocalNotificationMessageWithValidConsequence() {
        // setup
        let details = ["title": "local", "sound": "bell", "category": "appStart", "date": Date().timeIntervalSince1970, "content": "some content", "wait": 0, "userData": ["broadlogId": "h1bd500",
                                                                                                                                                                           "deliveryId": "13ccd4c"], "template": "local", "adb_deeplink": "http://mcias-mkt-dev1-t.adobedemo.com/r/?id=d1bd500,13ccd4c,13ccd88"] as [String: Any]
        let localNotificationConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = LocalNotificationMessage.createMessageObject(consequence: localNotificationConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNotNil(messageObject)
    }

    func testCreateLocalNotificationMessageWithConsequenceMissingContent() {
        // setup
        let details = ["title": "local", "wait": 0, "userData": ["broadlogId": "h1bd500",
                                                                 "deliveryId": "13ccd4c"], "template": "local", "adb_deeplink": "http://mcias-mkt-dev1-t.adobedemo.com/r/?id=d1bd500,13ccd4c,13ccd88"] as [String: Any]
        let localNotificationConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = LocalNotificationMessage.createMessageObject(consequence: localNotificationConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateLocalNotificationMessageWithNilConsequence() {
        // test
        let messageObject = LocalNotificationMessage.createMessageObject(consequence: nil, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateLocalNotificationMessageWithEmptyDetailDictionary() {
        // setup
        let localNotificationConsequence = RuleConsequence(id: "20761932", type: "iam", details: [:])
        // test
        let messageObject = LocalNotificationMessage.createMessageObject(consequence: localNotificationConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateLocalNotificationMessageWithContentOnly() {
        // setup
        let details = ["content": "some content"] as [String: Any]
        let localNotificationConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = LocalNotificationMessage.createMessageObject(consequence: localNotificationConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNotNil(messageObject)
    }

    // MARK: showMessage tests
    func testLocalNotificationShowMessageHappy() {
        // setup
        let details = ["title": "local", "sound": "bell", "category": "appStart", "date": Date().timeIntervalSince1970, "content": "some content", "wait": 0, "userData": ["broadlogId": "h1bd500",
                                                                                                                                                                           "deliveryId": "13ccd4c"], "template": "local", "adb_deeplink": "http://mcias-mkt-dev1-t.adobedemo.com/r/?id=d1bd500,13ccd4c,13ccd88"] as [String: Any]
        let localNotificationConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = LocalNotificationMessage.createMessageObject(consequence: localNotificationConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        })
        // test
        messageObject?.showMessage()
        // verify
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
        let messageInfoEvent = dispatchedEvents[1]
        verifyGenericDataOsEvent(event: messageInfoEvent)
    }

    func testLocalNotificationShowMessageNoBroadlogId() {
        // setup
        let details = ["title": "local", "sound": "bell", "category": "appStart", "date": Date().timeIntervalSince1970, "content": "some content", "wait": 0, "userData": [
            "deliveryId": "13ccd4c"], "template": "local", "adb_deeplink": "http://mcias-mkt-dev1-t.adobedemo.com/r/?id=d1bd500,13ccd4c,13ccd88"] as [String: Any]
        let localNotificationConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = LocalNotificationMessage.createMessageObject(consequence: localNotificationConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        })
        // test
        messageObject?.showMessage()
        // only a triggered event should be dispatched
        XCTAssertEqual(1, dispatchedEvents.count)
        // verify triggered event
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testLocalNotificationShowMessageNoDeliveryId() {
        // setup
        let details = ["title": "local", "sound": "bell", "category": "appStart", "date": Date().timeIntervalSince1970, "content": "some content", "wait": 0, "userData": [
            "broadlogId": "h1bd500"], "template": "local", "adb_deeplink": "http://mcias-mkt-dev1-t.adobedemo.com/r/?id=d1bd500,13ccd4c,13ccd88"] as [String: Any]
        let localNotificationConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = LocalNotificationMessage.createMessageObject(consequence: localNotificationConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        })
        // test
        messageObject?.showMessage()
        // only a triggered event should be dispatched
        XCTAssertEqual(1, dispatchedEvents.count)
        // verify triggered event
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testLocalNotificationShowMessageMissingContent() {
        // setup
        let details = ["title": "local", "sound": "bell", "category": "appStart", "date": Date().timeIntervalSince1970, "wait": 0, "userData": ["broadlogId": "h1bd500",
                                                                                                                                                "deliveryId": "13ccd4c"], "template": "local", "adb_deeplink": "http://mcias-mkt-dev1-t.adobedemo.com/r/?id=d1bd500,13ccd4c,13ccd88"] as [String: Any]
        let localNotificationConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = LocalNotificationMessage.createMessageObject(consequence: localNotificationConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        })
        // test
        messageObject?.showMessage()
        // verify no events sent due to missing content
        XCTAssertEqual(0, dispatchedEvents.count)
    }

    func testLocalNotificationShowMessageEmptyContent() {
        // setup
        let details = ["title": "local", "sound": "bell", "category": "appStart", "date": Date().timeIntervalSince1970, "content": "", "wait": 0, "userData": ["broadlogId": "h1bd500",
                                                                                                                                                               "deliveryId": "13ccd4c"], "template": "local", "adb_deeplink": "http://mcias-mkt-dev1-t.adobedemo.com/r/?id=d1bd500,13ccd4c,13ccd88"] as [String: Any]
        let localNotificationConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = LocalNotificationMessage.createMessageObject(consequence: localNotificationConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        })
        // test
        messageObject?.showMessage()
        // verify no events sent due to empty content
        XCTAssertEqual(0, dispatchedEvents.count)
    }

}
