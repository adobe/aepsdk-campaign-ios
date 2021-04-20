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
    var hitProcessor: HitProcessing!
    var dataQueue: DataQueue!
    var networking: MockNetworking!
    
    override func setUpWithError() throws {
        extensionRuntime = TestableExtensionRuntime()
        campaign = Campaign(runtime: extensionRuntime)
        
        dataQueue = MockDataQueue()
        hitProcessor = MockHitProcessor()
        hitQueue = PersistentHitQueue(dataQueue: dataQueue, processor: hitProcessor)
        state = CampaignState(hitQueue: hitQueue)
        ServiceProvider.shared.networkService = MockNetworking()
        
        campaign.onRegistered()
        campaign.state = state
    }
    
    func testGenericDataOSEventTriggerCampaignHit() {
        let campaignServer = "mcias-campaign.com"
        let ecid = "ecid"
        let broadLogId = "broadlogId"
        let deliveryId = "deliveryId"
        let action = "1"
        //Setup
        var sharedStates = [String:[String: Any]]()
        sharedStates[CampaignConstants.Identity.EXTENSION_NAME] = [
                        CampaignConstants.Identity.EXPERIENCE_CLOUD_ID: ecid]
                     
        sharedStates[CampaignConstants.Configuration.EXTENSION_NAME] = [
            CampaignConstants.Configuration.CAMPAIGN_SERVER: campaignServer,
            CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue
        ]
        
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)
        
        //Action
        let mockHitProcessor = hitProcessor as! MockHitProcessor
        mockHitProcessor.processResult = true
        state.update(dataMap: sharedStates)
        extensionRuntime.simulateComingEvents(genericDataOsEvent)
        
        //Assertion
        
        Thread.sleep(forTimeInterval: 1)
        XCTAssert(mockHitProcessor.processedEntities.count > 0)
        let dataEntity = mockHitProcessor.processedEntities[0]
        let hit = try? JSONDecoder().decode(CampaignHit.self, from: dataEntity.data!) as! CampaignHit
        XCTAssert(hit != nil)
        XCTAssertEqual(hit?.url.absoluteString, "https://\(campaignServer)/r?id=\(broadLogId),\(deliveryId),\(action)&mcId=\(ecid)")
    }
    
    func testGenericDataOSEventFailsWhenNoBroadLogId() {
        let campaignServer = "mcias-campaign.com"
        let ecid = "ecid"
        let deliveryId = "deliveryId"
        let action = "1"
        //Setup
        var sharedStates = [String:[String: Any]]()
        sharedStates[CampaignConstants.Identity.EXTENSION_NAME] = [
                        CampaignConstants.Identity.EXPERIENCE_CLOUD_ID: ecid]
                     
        sharedStates[CampaignConstants.Configuration.EXTENSION_NAME] = [
            CampaignConstants.Configuration.CAMPAIGN_SERVER: campaignServer,
            CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue
        ]
        
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)
        
        //Action
        let mockHitProcessor = hitProcessor as! MockHitProcessor
        mockHitProcessor.processResult = true
        state.update(dataMap: sharedStates)
        extensionRuntime.simulateComingEvents(genericDataOsEvent)
        
        //Assertion
        
        Thread.sleep(forTimeInterval: 1)
        XCTAssert(mockHitProcessor.processedEntities.count == 0)
    }
    
    func testGenericDataOSEventFailsWhenNoAction() {
        let campaignServer = "mcias-campaign.com"
        let ecid = "ecid"
        let broadLogId = "broadlogId"
        let deliveryId = "deliveryId"
        //Setup
        var sharedStates = [String:[String: Any]]()
        sharedStates[CampaignConstants.Identity.EXTENSION_NAME] = [
                        CampaignConstants.Identity.EXPERIENCE_CLOUD_ID: ecid]
                     
        sharedStates[CampaignConstants.Configuration.EXTENSION_NAME] = [
            CampaignConstants.Configuration.CAMPAIGN_SERVER: campaignServer,
            CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue
        ]
        
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)
        
        //Action
        let mockHitProcessor = hitProcessor as! MockHitProcessor
        mockHitProcessor.processResult = true
        state.update(dataMap: sharedStates)
        extensionRuntime.simulateComingEvents(genericDataOsEvent)
        
        //Assertion
        
        Thread.sleep(forTimeInterval: 1)
        XCTAssert(mockHitProcessor.processedEntities.count == 0)
    }
    
    func testGenericDataOSEventFailsWhenNoDeliveryId() {
        let campaignServer = "mcias-campaign.com"
        let ecid = "ecid"
        let broadLogId = "broadlogId"
        let action = "1"
        //Setup
        var sharedStates = [String:[String: Any]]()
        sharedStates[CampaignConstants.Identity.EXTENSION_NAME] = [
                        CampaignConstants.Identity.EXPERIENCE_CLOUD_ID: ecid]
                     
        sharedStates[CampaignConstants.Configuration.EXTENSION_NAME] = [
            CampaignConstants.Configuration.CAMPAIGN_SERVER: campaignServer,
            CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue
        ]
        
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)
        
        //Action
        let mockHitProcessor = hitProcessor as! MockHitProcessor
        mockHitProcessor.processResult = true
        state.update(dataMap: sharedStates)
        extensionRuntime.simulateComingEvents(genericDataOsEvent)
        
        //Assertion
        
        Thread.sleep(forTimeInterval: 1)
        XCTAssert(mockHitProcessor.processedEntities.count == 0)
    }
    
    func testGenericDataOSEventFailsWhenNoCampaignServer() {
        let ecid = "ecid"
        let broadLogId = "broadlogId"
        let deliveryId = "deliveryId"
        let action = "1"
        //Setup
        var sharedStates = [String:[String: Any]]()
        sharedStates[CampaignConstants.Identity.EXTENSION_NAME] = [
                        CampaignConstants.Identity.EXPERIENCE_CLOUD_ID: ecid]
                     
        sharedStates[CampaignConstants.Configuration.EXTENSION_NAME] = [
            CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue
        ]
        
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)
        
        //Action
        let mockHitProcessor = hitProcessor as! MockHitProcessor
        mockHitProcessor.processResult = true
        state.update(dataMap: sharedStates)
        extensionRuntime.simulateComingEvents(genericDataOsEvent)
        
        //Assertion
        
        Thread.sleep(forTimeInterval: 1)
        XCTAssert(mockHitProcessor.processedEntities.count == 0)
    }
    
    func testGenericDataOSEventFailsWhenNoEcid() {
        let campaignServer = "mcias-campaign.com"
        let broadLogId = "broadlogId"
        let deliveryId = "deliveryId"
        let action = "1"
        //Setup
        var sharedStates = [String:[String: Any]]()
                     
        sharedStates[CampaignConstants.Configuration.EXTENSION_NAME] = [
            CampaignConstants.Configuration.CAMPAIGN_SERVER: campaignServer,
            CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue
        ]
        
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)
        
        //Action
        let mockHitProcessor = hitProcessor as! MockHitProcessor
        mockHitProcessor.processResult = true
        state.update(dataMap: sharedStates)
        extensionRuntime.simulateComingEvents(genericDataOsEvent)
        
        //Assertion
        
        Thread.sleep(forTimeInterval: 1)
        XCTAssert(mockHitProcessor.processedEntities.count == 0)
    }
    
    func testGenericDataOSEventFailsWhenOptedOut() {
        let campaignServer = "mcias-campaign.com"
        let ecid = "ecid"
        let broadLogId = "broadlogId"
        let deliveryId = "deliveryId"
        let action = "1"
        //Setup
        var sharedStates = [String:[String: Any]]()
        sharedStates[CampaignConstants.Identity.EXTENSION_NAME] = [
                        CampaignConstants.Identity.EXPERIENCE_CLOUD_ID: ecid]
                     
        sharedStates[CampaignConstants.Configuration.EXTENSION_NAME] = [
            CampaignConstants.Configuration.CAMPAIGN_SERVER: campaignServer,
            CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedOut.rawValue
        ]
        
        let eventData = [
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_BROADLOG_ID: broadLogId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_DELIVERY_ID: deliveryId,
            CampaignConstants.EventDataKeys.TRACK_INFO_KEY_ACTION: action
        ]
        let genericDataOsEvent = Event(name: "Generic data os", type: EventType.genericData, source: EventSource.os, data: eventData)
        
        //Action
        let mockHitProcessor = hitProcessor as! MockHitProcessor
        mockHitProcessor.processResult = true
        state.update(dataMap: sharedStates)
        extensionRuntime.simulateComingEvents(genericDataOsEvent)
        
        //Assertion
        
        Thread.sleep(forTimeInterval: 1)
        XCTAssert(mockHitProcessor.processedEntities.count == 0)                
    }
    
    func testGenericDataOSEventNoNetworkRequestWhenCampaignStateIsNil() {
        
        //Setup
        campaign.state = nil
        let event = Event(name: "Generic Data OS event", type: EventType.genericData, source: EventSource.os, data: [String: Any]())
        
        //Action
        extensionRuntime.simulateComingEvents(event)
        
        //Assert
        let mockNetworking = ServiceProvider.shared.networkService as! MockNetworking
        XCTAssertEqual(mockNetworking.cachedNetworkRequests.count, 0)
    }
}
