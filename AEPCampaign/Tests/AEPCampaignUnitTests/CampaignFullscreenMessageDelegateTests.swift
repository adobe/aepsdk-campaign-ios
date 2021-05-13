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

class CampaignFullscreenMessageDelegateTests: XCTestCase {

    var state: CampaignState!
    var dispatchedEvents: [Event] = []
    var mockFullscreenMessage: MockFullscreenMessage!
    var uiService: MockUIService!
    var rootViewController: UIViewController!
    // swiftlint:disable weak_delegate
    var campaignFullscreenMessageDelegate: CampaignFullscreenMessage!
    var shouldSDKHandleUrl = false
    let mockHtmlString = "mock html content with image from: https://images.com/image.jpg"

    override func setUp() {
        state = CampaignState()
        addStateData()
        uiService = MockUIService()
        ServiceProvider.shared.uiService = uiService
        // setup message object and mock fullscreen presentable
        let details = ["html": "fullscreenIam.html", "template": "fullscreen", "remoteAssets": []] as [String: Any]
        let fullscreenConsequence = RuleConsequence(id: "20761932", type: "iam", details: details)
        campaignFullscreenMessageDelegate = CampaignFullscreenMessage.createMessageObject(consequence: fullscreenConsequence, state: state, eventDispatcher: { name, type, source, data in
            self.dispatchedEvents.append(Event(name: name, type: type, source: source, data: data))
        }) as? CampaignFullscreenMessage
        mockFullscreenMessage = MockFullscreenMessage(payload: mockHtmlString, listener: campaignFullscreenMessageDelegate, isLocalImageUsed: false, messageMonitor: MessageMonitor())
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

    func testOnDismiss() {
        // test
        campaignFullscreenMessageDelegate.onDismiss(message: mockFullscreenMessage)
        // verify
        let messageDismissedEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageDismissedEvent as Any, "actionType": "viewed", "size": 2] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
    }

    func testOverrideUrlLoadConfirmPressed() {
        // test
        shouldSDKHandleUrl = campaignFullscreenMessageDelegate.overrideUrlLoad(message: mockFullscreenMessage, url: "adbinapp://confirm/?id=h18a880,103b8f5,3")
        // verify
        let messageConfirmEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageConfirmEvent as Any, "actionType": "clicked", "size": 4, "type": "confirm", "id": "h18a880,103b8f5,3", "expectedComponents": ["confirm", "h18a880,103b8f5,3"]] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
        XCTAssertTrue(shouldSDKHandleUrl)
    }

    func testOverrideUrlLoadCancelPressed() {
        // test
        shouldSDKHandleUrl = campaignFullscreenMessageDelegate.overrideUrlLoad(message: mockFullscreenMessage, url: "adbinapp://cancel?id=h18a880,103b8f5,5")
        // verify
        let messageCancelEvent = dispatchedEvents[0]
        let messageParameters = ["event": messageCancelEvent as Any, "actionType": "clicked", "size": 4, "type": "cancel", "id": "h18a880,103b8f5,5", "expectedComponents": ["cancel", "h18a880,103b8f5,5"]] as [String: Any]
        verifyCampaignResponseEvent(expectedParameters: messageParameters)
        XCTAssertTrue(shouldSDKHandleUrl)
    }

    func testOverrideUrlLoadNilUrl() {
        // test
        shouldSDKHandleUrl = campaignFullscreenMessageDelegate.overrideUrlLoad(message: mockFullscreenMessage, url: nil)
        // verify
        XCTAssertEqual(0, dispatchedEvents.count)
        XCTAssertFalse(shouldSDKHandleUrl)
    }

    func testOverrideUrlLoadEmptyUrl() {
        // test
        shouldSDKHandleUrl = campaignFullscreenMessageDelegate.overrideUrlLoad(message: mockFullscreenMessage, url: "")
        // verify
        XCTAssertEqual(0, dispatchedEvents.count)
        XCTAssertFalse(shouldSDKHandleUrl)
    }

    func testOverrideUrlLoadInvalidDeeplinkUrl() {
        // test
        shouldSDKHandleUrl = campaignFullscreenMessageDelegate.overrideUrlLoad(message: mockFullscreenMessage, url: "adbinapp://12345")
        // verify
        XCTAssertEqual(0, dispatchedEvents.count)
        XCTAssertFalse(shouldSDKHandleUrl)
    }

    func testOverrideUrlLoadNonAdobeDeeplink() {
        // test
        shouldSDKHandleUrl = campaignFullscreenMessageDelegate.overrideUrlLoad(message: mockFullscreenMessage, url: "deeplink://deeplink")
        // verify
        XCTAssertEqual(0, dispatchedEvents.count)
        XCTAssertFalse(shouldSDKHandleUrl)
    }

    func testOverrideUrlLoadInvalidQueryParams() {
        // test
        shouldSDKHandleUrl = campaignFullscreenMessageDelegate.overrideUrlLoad(message: mockFullscreenMessage, url: "adbinapp://confirm?")
        // verify
        XCTAssertEqual(0, dispatchedEvents.count)
        XCTAssertFalse(shouldSDKHandleUrl)
    }

    func testOverrideUrlLoadLocalFileUrl() {
        // test
        shouldSDKHandleUrl = campaignFullscreenMessageDelegate.overrideUrlLoad(message: mockFullscreenMessage, url: "file://someLocalFile.zip")
        // verify
        XCTAssertEqual(0, dispatchedEvents.count)
        XCTAssertTrue(shouldSDKHandleUrl)
    }
}
