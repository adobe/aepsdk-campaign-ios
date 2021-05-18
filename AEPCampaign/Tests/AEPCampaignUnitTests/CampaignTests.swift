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
@testable import AEPCampaign
import AEPServices
import AEPCore

class CampaignTests: XCTestCase {

    var campaign: Campaign!
    var extensionRuntime: TestableExtensionRuntime!
    var state: CampaignState!
    var hitQueue: HitQueuing!
    var hitProcessor: MockHitProcessor!
    var dataQueue: DataQueue!
    var networking: MockNetworking!
    var mockDiskCache: MockDiskCache!
    var mockRulesEngine: MockRulesEngine!
    let ecid = "ecid"
    let campaignServer = "campaign.com"
    let mcias = "mciasServer"
    let propertyId = "propertId"
    let pkey = "pkey"

    ///Shared states
    var identitySharedState: [String: Any]!
    var configurationSharedState: [String: Any]!

    override func setUp() {
        extensionRuntime = TestableExtensionRuntime()
        campaign = Campaign(runtime: extensionRuntime)

        dataQueue = MockDataQueue()
        hitProcessor = MockHitProcessor()
        hitProcessor.processResult = true
        hitQueue = PersistentHitQueue(dataQueue: dataQueue, processor: hitProcessor)
        state = CampaignState()
        state.hitQueue = hitQueue

        networking = MockNetworking()
        ServiceProvider.shared.networkService = networking

        campaign.onRegistered()
        campaign.state = state

        mockDiskCache = MockDiskCache()
        ServiceProvider.shared.cacheService = mockDiskCache

        mockRulesEngine = MockRulesEngine(name: "\(CampaignConstants.EXTENSION_NAME).rulesengine", extensionRuntime: extensionRuntime)
        campaign.rulesEngine = mockRulesEngine
        setUpSharedStates()
    }

    private func setUpSharedStates() {
        identitySharedState = [
            CampaignConstants.Identity.EXPERIENCE_CLOUD_ID: ecid
        ]
        configurationSharedState = [
            CampaignConstants.Configuration.CAMPAIGN_SERVER: campaignServer,
            CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue,
            CampaignConstants.Configuration.CAMPAIGN_MCIAS: mcias,
            CampaignConstants.Configuration.PROPERTY_ID: propertyId,
            CampaignConstants.Configuration.CAMPAIGN_PKEY: pkey
        ]

        extensionRuntime.simulateSharedState(for: CampaignConstants.Identity.EXTENSION_NAME, data: (identitySharedState, .set))

        extensionRuntime.simulateSharedState(for: CampaignConstants.Configuration.EXTENSION_NAME, data: (configurationSharedState, .set))
    }

    // MARK: Generic Data event tests
    func testGenericDataOSEventTriggerCampaignHit() {
        let campaignServer = "campaign.com"
        let ecid = "ecid"
        let broadLogId = "broadlogId"
        let deliveryId = "deliveryId"
        let action = "1"
        //Setup
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)

        //Action
        extensionRuntime.simulateComingEvents(genericDataOsEvent)

        //Assertion
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count > 0)
        let dataEntity = hitProcessor.processedEntities[0]
        guard let data = dataEntity.data else {
            XCTFail("Failed to get data")
            return
        }
        let hit = try? JSONDecoder().decode(CampaignHit.self, from: data)
        XCTAssert(hit != nil)
        XCTAssertEqual(hit?.url.absoluteString, "https://\(campaignServer)/r?id=\(broadLogId),\(deliveryId),\(action)&mcId=\(ecid)")
    }

    func testGenericDataOSEventFailsWhenNoBroadLogId() {
        let deliveryId = "deliveryId"
        let action = "1"
        //Setup
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)

        //Action
        extensionRuntime.simulateComingEvents(genericDataOsEvent)

        //Assertion
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
    }

    func testGenericDataOSEventFailsWhenNoAction() {
        let broadLogId = "broadlogId"
        let deliveryId = "deliveryId"
        //Setup
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)

        //Action
        extensionRuntime.simulateComingEvents(genericDataOsEvent)

        //Assertion
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
    }

    func testGenericDataOSEventFailsWhenNoDeliveryId() {
        let broadLogId = "broadlogId"
        let action = "1"
        //Setup
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)

        //Action
        extensionRuntime.simulateComingEvents(genericDataOsEvent)

        //Assertion
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
    }

    func testGenericDataOSEventFailsWhenNoCampaignServer() {
        let broadLogId = "broadlogId"
        let deliveryId = "deliveryId"
        let action = "1"
        //Setup
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)

        //Action
        extensionRuntime.simulateComingEvents(genericDataOsEvent)

        //Assertion
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
    }

    func testGenericDataOSEventFailsWhenNoEcid() {
        let broadLogId = "broadlogId"
        let deliveryId = "deliveryId"
        let action = "1"
        //Setup
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)

        //Action
        extensionRuntime.simulateComingEvents(genericDataOsEvent)

        //Assertion
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
    }

    func testGenericDataOSEventFailsWhenOptedOut() {
        let broadLogId = "broadlogId"
        let deliveryId = "deliveryId"
        let action = "1"
        //Setup
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)

        //Action
        extensionRuntime.simulateComingEvents(genericDataOsEvent)

        //Assertion
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
    }

    // MARK: Lifecycle Response event (Registration) tests
    func testLifecycleResponseEventTriggersCampaignRegistrationRequest() {
        // test
        let lifecycleResponseEvent = Event(name: "Lifecycle Response Event", type: EventType.lifecycle, source: EventSource.responseContent, data: nil)
        extensionRuntime.simulateComingEvents(lifecycleResponseEvent)

        // verify
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count > 0)
        let dataEntity = hitProcessor.processedEntities[0]
        guard let data = dataEntity.data else {
            XCTFail("Failed to get data")
            return
        }
        let hit = try? JSONDecoder().decode(CampaignHit.self, from: data)
        XCTAssert(hit != nil)
        XCTAssertEqual(hit?.url.absoluteString, "https://\(campaignServer)/rest/head/mobileAppV5/\(pkey)/subscriptions/\(ecid)")
    }

    func testLifecycleResponseEventNoCampaignRegistrationRequestWhenCampaignServerIsNil() {
        // test
        let lifecycleResponseEvent = Event(name: "Lifecycle Response Event", type: EventType.lifecycle, source: EventSource.responseContent, data: nil)
        extensionRuntime.simulateComingEvents(lifecycleResponseEvent)

        // verify
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
    }

    func testLifecycleResponseEventNoCampaignRegistrationRequestWhenCampaignPkeyIsNil() {
        // test
        let lifecycleResponseEvent = Event(name: "Lifecycle Response Event", type: EventType.lifecycle, source: EventSource.responseContent, data: nil)
        extensionRuntime.simulateComingEvents(lifecycleResponseEvent)

        // verify
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
    }

    func testLifecycleResponseEventNoCampaignRegistrationRequestWhenPrivacyIsOptedOut() {
        // test
        let lifecycleResponseEvent = Event(name: "Lifecycle Response Event", type: EventType.lifecycle, source: EventSource.responseContent, data: nil)
        extensionRuntime.simulateComingEvents(lifecycleResponseEvent)

        // verify
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
    }

    func testLifecycleResponseEventQueuedCampaignRegistrationRequestWhenPrivacyIsUnknown() {
        // test
        let lifecycleResponseEvent = Event(name: "Lifecycle Response Event", type: EventType.lifecycle, source: EventSource.responseContent, data: nil)
        extensionRuntime.simulateComingEvents(lifecycleResponseEvent)

        // verify
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
        // the hit should be queued
        XCTAssert(hitQueue.count() == 1)
    }

    func testLifecycleResponseEventNoCampaignRegistrationRequestWhenThereIsNoECIDInSharedState() {
        // test
        let lifecycleResponseEvent = Event(name: "Lifecycle Response Event", type: EventType.lifecycle, source: EventSource.responseContent, data: nil)
        extensionRuntime.simulateComingEvents(lifecycleResponseEvent)

        // verify
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssert(hitProcessor.processedEntities.count == 0)
    }

    //MARK:- Unit tests for CampaignRequestIdentity and CampaignRequestReset Events handling.

    func testCampaignRequestIdentityEventSuccess() {

        let linkageFields = ["key1": "value1", "key2": "value2"]
        guard let linkageFieldsData = try? JSONEncoder().encode(linkageFields) else {
            XCTFail("Error in JSON encoding Linkage fields")
            return
        }
        let jsonEncodedLinkageFields = String.init(data: linkageFieldsData, encoding: .utf8)
        let eventData = [CampaignConstants.EventDataKeys.LINKAGE_FIELDS: linkageFields]

        let campaignRequestIdentityEvent = Event(name: "Campaign Request Identity", type: EventType.campaign, source: EventSource.requestIdentity, data: eventData)

        //Action
        extensionRuntime.simulateComingEvents(campaignRequestIdentityEvent)
        Thread.sleep(forTimeInterval: 1)

        //Assert
        XCTAssertTrue(mockDiskCache.isRemoveCacheItemCalled)
        XCTAssertEqual(networking.cachedNetworkRequests.count, 1)
        let networkRequest = networking.cachedNetworkRequests[0]
        XCTAssertNotNil(networkRequest.httpHeaders[CampaignConstants.Campaign.LINKAGE_FIELD_NETWORK_HEADER])
        guard let linkageFieldHeaderBase64 = networkRequest.httpHeaders[CampaignConstants.Campaign.LINKAGE_FIELD_NETWORK_HEADER] else {
            XCTFail("Expected value Linkage Field is missing in network request headers.")
            return
        }
        guard let data = Data(base64Encoded: linkageFieldHeaderBase64) else {
            XCTFail("Unable to convert Linkage fields header to Data Type.")
            return
        }
        let linkageFieldHeader = String.init(data: data, encoding: .utf8)
        XCTAssertEqual(linkageFieldHeader, jsonEncodedLinkageFields)
    }

    func testCampaignRequestIdentityEventFailure() {
        let campaignRequestIdentityEvent = Event(name: "Campaign Request Identity", type: EventType.campaign, source: EventSource.requestIdentity, data: nil)

        //Action
        extensionRuntime.simulateComingEvents(campaignRequestIdentityEvent)

        //Asserts
        XCTAssertFalse(mockDiskCache.isRemoveCacheItemCalled)
        XCTAssertEqual(networking.cachedNetworkRequests.count, 0)
    }

    func testCampaignRequestResetEvent() {
        //setup
        let httpConnection = HttpConnection(data: nil, response: nil, error: nil)
        networking.expectedResponse = httpConnection

        let linkageFields = ["key1": "value1", "key2": "value2"]
        let eventData = [CampaignConstants.EventDataKeys.LINKAGE_FIELDS: linkageFields]

        let campaignRequestIdentityEvent = Event(name: "Campaign Request Identity", type: EventType.campaign, source: EventSource.requestIdentity, data: eventData)
        //Action
        extensionRuntime.simulateComingEvents(campaignRequestIdentityEvent)
        Thread.sleep(forTimeInterval: 1)
        let campaignRequestResetEvent = Event(name: "Campaign Request Reset", type: EventType.campaign, source: EventSource.requestReset, data: nil)
        extensionRuntime.simulateComingEvents(campaignRequestResetEvent)
        Thread.sleep(forTimeInterval: 10)

        //Assert
        XCTAssertEqual(networking.cachedNetworkRequests.count, 2)
        XCTAssertNotNil(networking.cachedNetworkRequests[0].httpHeaders[CampaignConstants.Campaign.LINKAGE_FIELD_NETWORK_HEADER])
        XCTAssertTrue(mockDiskCache.isRemoveCacheItemCalled)
        XCTAssertNil(networking.cachedNetworkRequests[1].httpHeaders[CampaignConstants.Campaign.LINKAGE_FIELD_NETWORK_HEADER])
        XCTAssertTrue(mockRulesEngine.isReplaceRulesCalled)
        XCTAssertEqual(mockRulesEngine.rules?.count, 0)
    }
}
