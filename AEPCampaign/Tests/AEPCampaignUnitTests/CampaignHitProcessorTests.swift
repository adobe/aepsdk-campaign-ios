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

class CampaignHitProcessorTests: XCTestCase {

    var hitProcessor: CampaignHitProcessor!
    var dataQueue: MockDataQueue!
    var state: CampaignState!
    var responseCallbackArgs = [CampaignHit]()
    var mockNetworkService: MockNetworking? {
        return ServiceProvider.shared.networkService as? MockNetworking
    }
    
    func addStateData(customConfig: [String: Any]? = nil) {
        var configurationData = [String: Any]()
        configurationData[CampaignConstants.Configuration.CAMPAIGN_SERVER] = "campaign-server"
        configurationData[CampaignConstants.Configuration.CAMPAIGN_PKEY] = "pkey"
        configurationData[CampaignConstants.Configuration.PROPERTY_ID] = "propertyId"
        configurationData[CampaignConstants.Configuration.CAMPAIGN_TIMEOUT] = 5
        configurationData[CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY] = PrivacyStatus.optedIn.rawValue
        configurationData.merge(customConfig ?? [:]) { _, new in new }
        var identityData = [String: Any]()
        identityData[CampaignConstants.Identity.EXPERIENCE_CLOUD_ID] = "ecid"
        var dataMap = [String: [String: Any]]()
        dataMap[CampaignConstants.Configuration.EXTENSION_NAME] = configurationData
        dataMap[CampaignConstants.Identity.EXTENSION_NAME] = identityData
        state.update(dataMap: dataMap)
    }
    
    override func setUp() {
        ServiceProvider.shared.networkService = MockNetworking()
        state = CampaignState(hitQueue: PersistentHitQueue(dataQueue: dataQueue, processor: hitProcessor))
        addStateData()
        dataQueue = MockDataQueue()
        hitProcessor = CampaignHitProcessor(timeout: state.campaignTimeout, responseHandler: { [weak self] data in
            self?.responseCallbackArgs.append(data)
        })
    }
    
    func testProcessHitSuccessful() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let expectedUrl = URL.getCampaignProfileUrl(state: state)
        let expectedBody = URL.buildBody(state: state, data: nil)
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl!, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)

        let hit = CampaignHit(url: expectedUrl, payload: expectedBody, timestamp: Date().timeIntervalSince1970)

        let entity = DataEntity(uniqueIdentifier: UUID().uuidString, timestamp: Date(), data: try! JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 1)

        XCTAssertFalse(responseCallbackArgs.isEmpty) // response handler should have been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
        let actualUrlString = mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url.absoluteString ?? ""
        let expectedUrlString = expectedUrl?.absoluteString ?? ""
    }
}
