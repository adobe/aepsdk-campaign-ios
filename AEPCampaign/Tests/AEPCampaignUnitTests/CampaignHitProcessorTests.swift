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
    var responseCallbackArgs = [CampaignHit]()
    var mockNetworkService: MockNetworking? {
        return ServiceProvider.shared.networkService as? MockNetworking
    }

    override func setUp() {
        ServiceProvider.shared.networkService = MockNetworking()
        dataQueue = MockDataQueue()
        hitProcessor = CampaignHitProcessor(timeout: TimeInterval(5), responseHandler: { [weak self] data in
            self?.responseCallbackArgs.append(data)
        })
    }

    /// Tests that when a `DataEntity` with bad data is passed, that it is not retried and is removed from the queue
    func testProcessBadHit() {
        // setup
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: nil) // entity data does not contain a `CampaignHit`
        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(responseCallbackArgs.isEmpty) // response handler should not have been invoked
        XCTAssertFalse(mockNetworkService?.connectAsyncCalled ?? true) // no network request should have been made
    }

    /// Tests that when a good hit is processed that a network request is made and the request returns 200
    func testProcessHitSuccessful() {
        // setup
        let server = "campaign-server"
        let pkey = "pkey"
        let ecid = "ecid"
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        guard let expectedUrl = URL.getCampaignProfileUrl(campaignServer: server, pkey: pkey, ecid: ecid) else {
            XCTFail("Failed to build the request url")
            return
        }
        guard let expectedBody = URL.buildBody(ecid: ecid, data: nil) else {
            XCTFail("Failed to build the request body")
            return
        }
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)

        let hit = CampaignHit(url: expectedUrl, payload: expectedBody, timestamp: Date().timeIntervalSince1970)
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try? JSONEncoder().encode(hit))

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
        let expectedUrlString = expectedUrl.absoluteString
        XCTAssertEqual(actualUrlString, expectedUrlString) // network request should be made with the url in the hit
        let actualBody = mockNetworkService?.connectAsyncCalledWithNetworkRequest?.connectPayload
        XCTAssertEqual(expectedBody, actualBody)
    }

    /// Tests that when the network request fails but has a recoverable error that we will retry the hit and do not invoke the response handler for that hit
    func testProcessHitRecoverableNetworkError() {
        // setup
        let server = "campaign-server"
        let pkey = "pkey"
        let ecid = "ecid"
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        guard let expectedUrl = URL.getCampaignProfileUrl(campaignServer: server, pkey: pkey, ecid: ecid) else {
            XCTFail("Failed to build the request url")
            return
        }
        guard let expectedBody = URL.buildBody(ecid: ecid, data: nil) else {
            XCTFail("Failed to build the request body")
            return
        }
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl, statusCode: NetworkServiceConstants.RECOVERABLE_ERROR_CODES.first!, httpVersion: nil, headerFields: nil), error: nil)

        let hit = CampaignHit(url: expectedUrl, payload: expectedBody, timestamp: Date().timeIntervalSince1970)
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try? JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertFalse(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(responseCallbackArgs.isEmpty) // response handler should have not been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url, expectedUrl) // network request should be made with the url in the hit
    }

    /// Tests that when there is no network connectivity that we will retry the hit and do not invoke the response handler for that hit
    func testProcessHitRetryIfNoNetworkConnectivity() {
        // setup
        let server = "campaign-server"
        let pkey = "pkey"
        let ecid = "ecid"
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        guard let expectedUrl = URL.getCampaignProfileUrl(campaignServer: server, pkey: pkey, ecid: ecid) else {
            XCTFail("Failed to build the request url")
            return
        }
        guard let expectedBody = URL.buildBody(ecid: ecid, data: nil) else {
            XCTFail("Failed to build the request body")
            return
        }
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: nil, error: URLError(URLError.notConnectedToInternet))

        let hit = CampaignHit(url: expectedUrl, payload: expectedBody, timestamp: Date().timeIntervalSince1970)
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try? JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertFalse(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(responseCallbackArgs.isEmpty) // response handler should have not been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url, expectedUrl) // network request should be made with the url in the hit
    }

    /// Tests that when there is an unexpected error (anything other than URLError.notConnectedToInternet) that we do not invoke the response handler and do not retry the hit
    func testProcessHitUnexpectedNetworkError() {
        // setup
        enum error: Error {
            case genericError
        }
        let server = "campaign-server"
        let pkey = "pkey"
        let ecid = "ecid"
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        guard let expectedUrl = URL.getCampaignProfileUrl(campaignServer: server, pkey: pkey, ecid: ecid) else {
            XCTFail("Failed to build the request url")
            return
        }
        guard let expectedBody = URL.buildBody(ecid: ecid, data: nil) else {
            XCTFail("Failed to build the request body")
            return
        }
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: nil, error: error.genericError)

        let hit = CampaignHit(url: expectedUrl, payload: expectedBody, timestamp: Date().timeIntervalSince1970)
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try? JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(responseCallbackArgs.isEmpty) // response handler should have not been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url, expectedUrl) // network request should be made with the url in the hit
    }

    /// Tests that when the network request fails and does not have a recoverable response code that we do not invoke the response handler and do not retry the hit
    func testProcessHitUnrecoverableNetworkError() {
        let server = "campaign-server"
        let pkey = "pkey"
        let ecid = "ecid"
        let expectation = XCTestExpectation(description: "Callback should be invoked with true signaling this hit should not be retried")
        guard let expectedUrl = URL.getCampaignProfileUrl(campaignServer: server, pkey: pkey, ecid: ecid) else {
            XCTFail("Failed to build the request url")
            return
        }
        guard let expectedBody = URL.buildBody(ecid: ecid, data: nil) else {
            XCTFail("Failed to build the request body")
            return
        }
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: expectedUrl, statusCode: -1, httpVersion: nil, headerFields: nil), error: nil)

        let hit = CampaignHit(url: expectedUrl, payload: expectedBody, timestamp: Date().timeIntervalSince1970)
        let entity = DataEntity(uniqueIdentifier: "test-uuid", timestamp: Date(), data: try? JSONEncoder().encode(hit))

        // test
        hitProcessor.processHit(entity: entity) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        // verify
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(responseCallbackArgs.isEmpty) // response handler should have not been invoked
        XCTAssertTrue(mockNetworkService?.connectAsyncCalled ?? false) // network request should have been made
        XCTAssertEqual(mockNetworkService?.connectAsyncCalledWithNetworkRequest?.url, expectedUrl) // network request should be made with the url in the hit
    }
}
