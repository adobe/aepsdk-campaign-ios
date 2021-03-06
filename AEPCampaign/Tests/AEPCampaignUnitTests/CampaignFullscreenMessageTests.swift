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

    private let messageId = "20761932"

    var state: CampaignState!
    let fileManager = FileManager.default
    var dispatchedEvents: [Event] = []
    var mockFullscreenMessage: MockFullscreenMessage!
    var uiService: MockUIService!

    var rootViewController: UIViewController!
    let mockHtmlString = "mock html content with image from: https://images.com/image.jpg"
    let mockHtmlStringForLocalTest = "mock html content with image from: bundled.jpg"
    let mockRemoteImage = "mockRemoteImage"

    override func setUp() {
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

    func addRemoteImageToCache() {
        guard let cacheDir = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return
        }
        let messagesDir = cacheDir.appendingPathComponent(CampaignConstants.RulesDownloaderConstants.MESSAGE_CACHE_FOLDER).appendingPathComponent(messageId)
        let cachedRemoteImageFile = messagesDir.appendingPathComponent("httpsimagescomimagejpg")
        do {
            try fileManager.createDirectory(atPath: messagesDir.path, withIntermediateDirectories: true, attributes: nil)
            let data = Data(mockRemoteImage.utf8)
            try data.write(to: cachedRemoteImageFile, options: .atomic)
        } catch {
            print(error)
        }
    }

    func setupMockCache(forLocalTest: Bool) {
        var data = Data()
        // add fullscreen html to cache
        if !forLocalTest {
            data = Data(mockHtmlString.utf8)
        } else {
            data = Data(mockHtmlStringForLocalTest.utf8)
        }

        guard let cacheDir = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return
        }
        // clear cached files from previous tests
        clearContentsOf(cacheDir)
        let htmlDir = cacheDir.appendingPathComponent(CampaignConstants.RulesDownloaderConstants.RULES_CACHE_FOLDER).appendingPathComponent(CampaignConstants.Campaign.Rules.ASSETS_DIRECTORY)
        // write html file to assets directory
        let file = htmlDir.appendingPathComponent("fullscreenIam").appendingPathExtension("html")
        do {
            try fileManager.createDirectory(atPath: htmlDir.path, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: file, options: .atomic)
        } catch {
            print(error)
        }
    }

    func clearContentsOf(_ url: URL) {
        do {
            var contents = try fileManager.contentsOfDirectory(atPath: url.path)
            print("before cleaning: \(contents)")
            let urls = contents.map { URL(string: "\(url.appendingPathComponent("\($0)"))")! }
            urls.forEach {
                try? FileManager.default.removeItem(at: $0)
            }
            contents = try fileManager.contentsOfDirectory(atPath: url.path)
            print("after cleaning: \(contents)")
        } catch {
            print(error)
        }
    }

    // MARK: fullscreen message creation tests
    func testCreateFullscreenMessageWithValidConsequence() {
        // setup
        let details = ["html": "fullscreenIam.html", "template": "fullscreen"]
        let fullscreenConsequence = RuleConsequence(id: messageId, type: "iam", details: details)
        // test
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNotNil(messageObject)
    }

    func testCreateFullscreenMessageWithHtmlFilenameMissingInDetails() {
        // setup
        let details = ["template": "fullscreen"]
        let fullscreenConsequence = RuleConsequence(id: messageId, type: "iam", details: details)
        // test
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateFullscreenMessageWithEmptyDetailDictionary() {
        // setup
        let fullscreenConsequence = RuleConsequence(id: messageId, type: "iam", details: [:])
        // test
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    // MARK: showMessage tests
    func testFullscreenShowMessageHappy() {
        // setup
        setupMockCache(forLocalTest: false)
        let details = ["html": "fullscreenIam.html", "template": "fullscreen"]
        let fullscreenConsequence = RuleConsequence(id: messageId, type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        addRemoteImageToCache()
        // test
        messageObject?.showMessage()
        // verify
        XCTAssertTrue(uiService.createFullscreenMessageCalled)
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testFullscreenShowMessageWithEmptyCache() {
        // setup
        guard let cachedDir = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return
        }
        let htmlDir = cachedDir.appendingPathComponent(CampaignConstants.RulesDownloaderConstants.RULES_CACHE_FOLDER).appendingPathComponent(CampaignConstants.Campaign.Rules.ASSETS_DIRECTORY)
        // clear cached html
        clearContentsOf(htmlDir)
        let details = ["html": "fullscreenIam.html", "template": "fullscreen"]
        let fullscreenConsequence = RuleConsequence(id: messageId, type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
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
        setupMockCache(forLocalTest: false)
        let details = ["html": "", "template": "fullscreen"]
        let fullscreenConsequence = RuleConsequence(id: messageId, type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
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
        setupMockCache(forLocalTest: false)
        let details = ["template": "fullscreen"]
        let fullscreenConsequence = RuleConsequence(id: messageId, type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
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
        setupMockCache(forLocalTest: false)
        addRemoteImageToCache()
        let details = ["html": "fullscreenIam.html", "template": "fullscreen", "remoteAssets": [
            [
                "https://images.com/image.jpg",
                "local.jpg"
            ]
        ]] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: messageId, type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        // test
        messageObject?.showMessage()
        // verify
        XCTAssertTrue(uiService.createFullscreenMessageCalled)
        guard let payload = messageObject?.htmlPayload else {
            XCTFail("no html payload found")
            return
        }
        XCTAssertTrue(payload.contains("/Caches/\(CampaignConstants.RulesDownloaderConstants.MESSAGE_CACHE_FOLDER)/20761932/httpsimagescomimagejpg"))
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testFullscreenShowMessageUseLocalAssets() {
        // setup
        setupMockCache(forLocalTest: true)
        let details = ["html": "fullscreenIam.html", "template": "fullscreen", "remoteAssets": [
            [
                "bundled.jpg",
                "local.jpg"
            ]
        ]] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: messageId, type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        // test
        messageObject?.showMessage()
        // verify
        XCTAssertTrue(uiService.createFullscreenMessageCalled)
        // verify asset replaced with bundled asset
        guard let payload = messageObject?.htmlPayload else {
            XCTFail("no html payload found")
            return
        }
        // verify https://images.com/image.jpg is replaced with local.jpg from the UnitTestApp bundle
        XCTAssertTrue(payload.contains("UnitTestApp.app/local.jpg"))
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testFullscreenShowMessageWithEmptyAssetsArray() {
        // setup
        setupMockCache(forLocalTest: false)
        let details = ["html": "fullscreenIam.html", "template": "fullscreen", "remoteAssets": [[]]]  as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: messageId, type: "iam", details: details)
        let messageObject = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: messageObject, isLocalImageUsed: false, messageMonitor: MessageMonitor())
        uiService.fullscreenMessage = mockFullscreenMessage
        // test
        messageObject?.showMessage()
        // verify
        XCTAssertTrue(uiService.createFullscreenMessageCalled)
        // verify no asset replacement
        XCTAssertEqual("mock html content with image from: https://images.com/image.jpg", messageObject?.htmlPayload)
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }
}
