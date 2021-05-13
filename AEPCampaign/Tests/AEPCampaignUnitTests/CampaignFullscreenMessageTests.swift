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
import UIKit

class CampaignFullscreenMessageTests: XCTestCase {

    var state: CampaignState!
    let fileManager = FileManager.default
    var dispatchedEvents: [Event] = []
    var cache: MockCache!
    var mockFullscreenMessage: MockFullscreenMessage!
    var uiService: MockUIService!
    var rootViewController: UIViewController!
    let mockHtmlString = "mock html content with image from: https://images.com/image.jpg"

    override func setUp() {
        cache = MockCache(name: "rules.cache")
        uiService = MockUIService()
        ServiceProvider.shared.uiService = uiService
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

    func setupMockCache() {
        // clear cache
        cache.reset()

        // add fullscreen html to cache
        if let data = mockHtmlString.data(using: .utf8) {
            let cacheEntry = CacheEntry(data: data, expiry: .never, metadata: nil)
            try? cache.set(key: "campaignrules/assets/fullscreenIam.html", entry: cacheEntry)
        }
    }

    func addRemoteAssetToCache() {
        if let mockData = "remote image data".data(using: .utf8) {
            let asset = CacheEntry(data: mockData, expiry: .never, metadata: nil)
            cache.setCachedAssets(messageId: "20761932", url: "https://images.com/anotherimage.jpg".alphanumeric, entry: asset)
        }
    }

    // MARK: fullscreen message creation tests
    func testCreateFullscreenMessageWithValidConsequence() {
        // setup
        let details = ["html": "fullscreenIam.html", "template": "fullscreen"] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNotNil(messageObject)
    }

    func testCreateFullscreenMessageWithHtmlFilenameMissingInDetails() {
        // setup
        let details = ["template": "fullscreen"] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateFullscreenMessageWithNilConsequence() {
        // test
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: nil, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateFullscreenMessageWithEmptyDetailDictionary() {
        // setup
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: [:])
        // test
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    // MARK: showMessage tests
    func testFullscreenShowMessageHappy() {
        // setup
        setupMockCache()
        let details = ["html": "fullscreenIam.html", "template": "fullscreen"] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        messageObject?.cache = self.cache
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        // test
        messageObject?.showMessage()
        // verify
        XCTAssertTrue(uiService.createFullscreenMessageCalled)
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testFullscreenShowMessageWithEmptyCache() {
        // setup
        let details = ["html": "fullscreenIam.html", "template": "fullscreen"] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        messageObject?.cache = self.cache
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        // test
        messageObject?.showMessage()
        // verify no message shown due to empty cache
        XCTAssertFalse(uiService.createFullscreenMessageCalled)
        XCTAssertEqual(0, dispatchedEvents.count)
    }

    func testFullscreenShowMessageEmptyHTML() {
        // setup
        setupMockCache()
        let details = ["html": "", "template": "fullscreen"] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        messageObject?.cache = self.cache
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        // test
        messageObject?.showMessage()
        // verify no message shown and no events sent due to empty html
        XCTAssertFalse(uiService.createFullscreenMessageCalled)
        XCTAssertEqual(0, dispatchedEvents.count)
    }

    func testFullscreenShowMessageMissingHTML() {
        // setup
        setupMockCache()
        let details = ["template": "fullscreen"] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        messageObject?.cache = self.cache
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        // test
        messageObject?.showMessage()
        // verify no message shown and no events sent due to missing html
        XCTAssertFalse(uiService.createFullscreenMessageCalled)
        XCTAssertEqual(0, dispatchedEvents.count)
    }

    // MARK: Fullscreen message with assets tests
    func testFullscreenShowMessageWithAssetsHappy() {
        // setup
        setupMockCache()
        addRemoteAssetToCache()
        let details = ["html": "fullscreenIam.html", "template": "fullscreen", "remoteAssets": [
            [
                "https://images.com/image.jpg",
                "https://images.com/anotherimage.jpg"
            ]
        ]] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        messageObject?.cache = self.cache
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        // test
        messageObject?.showMessage()
        // verify
        XCTAssertTrue(uiService.createFullscreenMessageCalled)
        // verify asset replaced with cached asset
        guard let replacementAsset = messageObject?.replacementAsset else {
            XCTFail("no replacement asset found")
            return
        }
        guard let payload = messageObject?.htmlPayload else {
            XCTFail("no html payload found")
            return
        }
        XCTAssertTrue(payload.contains("/Caches/messages/20761932/httpsimagescomanotherimagejpg"))
        XCTAssertEqual(replacementAsset, "remote image data")
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testFullscreenShowMessageWithLocalAssets() {
        // setup
        setupMockCache()
        let details = ["html": "fullscreenIam.html", "template": "fullscreen", "remoteAssets": [
            [
                "https://images.com/image.jpg",
                "test.jpg"
            ]
        ]] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        messageObject?.cache = self.cache
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        // test
        messageObject?.showMessage()
        // verify
        XCTAssertTrue(uiService.createFullscreenMessageCalled)
        // verify asset replaced with cached asset
        guard let payload = messageObject?.htmlPayload else {
            XCTFail("no html payload found")
            return
        }
        XCTAssertEqual(payload, "mock html content with image from: test.jpg")
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testFullscreenShowMessageWithEmptyAssetsArray() {
        // setup
        setupMockCache()
        let details = ["html": "fullscreenIam.html", "template": "fullscreen", "remoteAssets": [[]]] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        messageObject?.cache = self.cache
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        // test
        messageObject?.showMessage()
        // verify
        XCTAssertTrue(uiService.createFullscreenMessageCalled)
        // verify no asset replacement
        XCTAssertEqual("mock html content with image from: https://images.com/image.jpg", messageObject?.htmlPayload)
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }
}
