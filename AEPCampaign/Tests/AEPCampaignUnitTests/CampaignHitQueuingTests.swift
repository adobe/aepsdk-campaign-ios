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

class CampaignHitQueuingTests: XCTestCase {

    var hitProcessor: MockHitProcessor!
    var dataQueue: MockDataQueue!
    var state: CampaignState!

    @discardableResult
    private func queueHits(numberOfHits: Int) -> [CampaignHit] {
        guard let testUrl = URL(string: "https://acs-test.com") else {
            XCTFail("Failed to create a test url")
            return []
        }
        var queuedHits: [CampaignHit] = []
        let ecid = state.ecid ?? ""
        for _ in 1 ... numberOfHits {
            guard let payload = URL.buildBody(ecid: ecid, data: nil) else {
                XCTFail("Failed to create request payload")
                return []
            }
            let hit = CampaignHit(url: testUrl, payload: payload, timestamp: Date().timeIntervalSince1970)
            state.hitQueue.queue(url: hit.url, payload: hit.payload, timestamp: hit.timestamp, privacyStatus: state.privacyStatus)
            queuedHits.append(hit)
        }
        return queuedHits
    }

    private func getHitFromDataEntityArray(hits: [DataEntity]) -> [CampaignHit] {
        var ret: [CampaignHit] = []
        for hit in hits {
            if let data = hit.data, let campaignHit = try? JSONDecoder().decode(CampaignHit.self, from: data) {
                ret.append(campaignHit)
            }
        }
        return ret
    }

    private func getProcessedHits() -> [CampaignHit] {
        return getHitFromDataEntityArray(hits: hitProcessor.processedEntities)
    }

    private func assertHit(_ expected: CampaignHit, _ actual: CampaignHit) {
        XCTAssertEqual(expected.payload, actual.payload)
        XCTAssertEqual(expected.timestamp, actual.timestamp, accuracy: 0.0000001)
    }

    private func assertHits(_ expected: [CampaignHit], _ actual: [CampaignHit]) {
        XCTAssertEqual(expected.count, actual.count)
        for (e1, e2) in zip(expected, actual) {
            assertHit(e1, e2)
        }
    }

    private func updatePrivacyStatus(status: PrivacyStatus) {
        var configurationData = [String: Any]()
        configurationData[CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY] = status.rawValue
        var dataMap = [String: [String: Any]]()
        dataMap[CampaignConstants.Configuration.EXTENSION_NAME] = configurationData
        state.update(dataMap: dataMap)
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

    override func setUp() {
        dataQueue = MockDataQueue()
        hitProcessor = MockHitProcessor()
        state = CampaignState(hitQueue: PersistentHitQueue(dataQueue: dataQueue, processor: hitProcessor))
        addStateData()
    }

    func testQueueHit() {
        // setup
        hitProcessor.processResult = true
        // set privacy status to opted in to allow immediate processing of queued hits
        updatePrivacyStatus(status: .optedIn)
        // test
        let queuedHit = queueHits(numberOfHits: 1)
        Thread.sleep(forTimeInterval: 0.5)
        // verify
        assertHits(queuedHit, getProcessedHits())
    }

    func testQueueHits() {
        // setup
        hitProcessor.processResult = true
        // test
        let queuedHits = queueHits(numberOfHits: 5)
        // verify
        XCTAssertEqual(5, state.hitQueue.count())
        // update privacy status to opted in to begin processing of queued hits
        updatePrivacyStatus(status: .optedIn)
        Thread.sleep(forTimeInterval: 0.5)
        assertHits(queuedHits, getProcessedHits())
    }

    func testQueueHitsWhenPrivacyIsOptedOut() {
        // setup
        updatePrivacyStatus(status: .optedOut)
        // test
        queueHits(numberOfHits: 2)
        // verify
        XCTAssertEqual(0, state.hitQueue.count())
    }

    func testQueueHitsWhenPrivacyUnknown() {
        // setup
        updatePrivacyStatus(status: .unknown)
        // test
        queueHits(numberOfHits: 2)
        // verify
        XCTAssertEqual(2, state.hitQueue.count())
        Thread.sleep(forTimeInterval: 0.5)
        assertHits([], getProcessedHits())
    }

    func testQueueHitsThenDatabaseClearedWhenPrivacyOptedOut() {
        // setup
        hitProcessor.processResult = true
        // test
        queueHits(numberOfHits: 5)
        // verify
        XCTAssertEqual(5, state.hitQueue.count())
        // update privacy status to opted out and verify the database is cleared
        updatePrivacyStatus(status: .optedOut)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(0, state.hitQueue.count())
    }
}
