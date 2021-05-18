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
import UIKit
@testable import AEPServices
@testable import AEPCore
@testable import AEPCampaign

class AlertMessageTests: XCTestCase {

    var state: CampaignState!
    let fileManager = FileManager.default
    var dispatchedEvents: [Event] = []
    var title = "Alert Title"
    var content = "Alert Content"
    var cancel = "Cancel"
    var confirm = "Confirm"
    var url = "https://www.adobe.com"

    override func setUp() {
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

    // MARK: alert message creation tests
    func testCreateAlertMessageWithValidConsequence() {
        // setup
        let details = ["title": title, "content": content, "cancel": cancel, "confirm": confirm, "url": url] as [String: Any]
        let alertConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = AlertMessage.createMessageObject(consequence: alertConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNotNil(messageObject)
    }

    func testCreateAlertMessageWithNoTitle() {
        // setup
        let details = ["content": content, "cancel": cancel] as [String: Any]
        let alertConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = AlertMessage.createMessageObject(consequence: alertConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateAlertMessageWithEmptyTitle() {
        // setup
        let details = ["title": "", "content": content, "cancel": cancel] as [String: Any]
        let alertConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = AlertMessage.createMessageObject(consequence: alertConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateAlertMessageWithNoContent() {
        // setup
        let details = ["title": title, "cancel": cancel] as [String: Any]
        let alertConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = AlertMessage.createMessageObject(consequence: alertConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateAlertMessageWithEmptyContent() {
        // setup
        let details = ["title": title, "content": "", "cancel": cancel] as [String: Any]
        let alertConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = AlertMessage.createMessageObject(consequence: alertConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateAlertMessageWithNoCancelText() {
        // setup
        let details = ["title": title, "content": content] as [String: Any]
        let alertConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = AlertMessage.createMessageObject(consequence: alertConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateAlertMessageWithEmptyCancelText() {
        // setup
        let details = ["title": title, "content": content, "cancel": ""] as [String: Any]
        let alertConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        // test
        let messageObject = AlertMessage.createMessageObject(consequence: alertConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateAlertMessageWithNilConsequence() {
        // test
        let messageObject = AlertMessage.createMessageObject(consequence: nil, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    func testCreateAlertMessageWithEmptyDetailDictionary() {
        // setup
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: [:])
        // test
        let messageObject = AlertMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { _, _, _, _ in })
        // verify
        XCTAssertNil(messageObject)
    }

    // MARK: showMessage tests
    func testAlertShowMessageHappy() {
        // setup
        let details = ["title": title, "content": content, "cancel": cancel, "confirm": confirm, "url": url] as [String: Any]
        let alertConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = AlertMessage.createMessageObject(consequence: alertConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? AlertMessage
        // test
        messageObject?.showMessage()
        // verify
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testAlertShowMessageCancelPressed() {
        // setup
        let details = ["title": title, "content": content, "cancel": cancel, "confirm": confirm, "url": url] as [String: Any]
        let alertConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        let messageObject = AlertMessage.createMessageObject(consequence: alertConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? AlertMessage
        // test
        messageObject?.showMessage()
        let alertController = try? XCTUnwrap(messageObject?.getAlertController())
        alertController?.tapButton(atIndex: 0) // button 0 is "cancel"
        // verify triggered then viewed event is sent
        let messageTriggeredEvent = dispatchedEvents[0]
        let messageTriggeredParameters = ["event": messageTriggeredEvent as Any, "actionType": "triggered", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageTriggeredParameters)
        let messageViewedEvent = dispatchedEvents[1]
        let messageViewedParameters = ["event": messageViewedEvent as Any, "actionType": "viewed", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageViewedParameters)
    }
}

/// Used to simulate alert message button presses
extension UIAlertController {
    typealias AlertHandler = @convention(block) (UIAlertAction) -> Void

    func tapButton(atIndex index: Int) {
        guard let block = actions[index].value(forKey: "handler") else { return }
        let handler = unsafeBitCast(block as AnyObject, to: AlertHandler.self)
        handler(actions[index])
    }
}
