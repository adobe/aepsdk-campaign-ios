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

import Foundation
import XCTest
@testable import AEPServices
@testable import AEPCore
@testable import AEPCampaign

class CampaignRulesDownloaderTests: XCTestCase {
    var campaignRulesDownloader: CampaignRulesDownloader!
    var extensionRuntime: ExtensionRuntime!
    var ruleEngine: MockRulesEngine!
    var mockDiskCache: MockDiskCache!
    var mockNetworking = MockNetworking()
    var campaignRulesCache = CampaignRulesCache()

    static var bundle: Bundle {
        Bundle(for: self)
    }

    static var campaignRulesJsonUrl: URL? {
        bundle.url(forResource: "rules", withExtension: ".json")
    }

    static var campaignRulesZipUrl: URL? {
        bundle.url(forResource: "rules", withExtension: ".zip")
    }

    override func setUp() {
        extensionRuntime = TestableExtensionRuntime()
        ruleEngine = MockRulesEngine(name: "\(CampaignConstants.EXTENSION_NAME).rulesengine", extensionRuntime: extensionRuntime)
        mockDiskCache = MockDiskCache()
        ServiceProvider.shared.cacheService = mockDiskCache
        ServiceProvider.shared.networkService = mockNetworking
    }

    func testLoadRulesFromCacheSuccess() {
        guard let rulesJsonUrl = Self.campaignRulesJsonUrl else {
            XCTFail("rules.json URL is nil")
            return
        }

        guard let data = try? Data(contentsOf: rulesJsonUrl) else {
            XCTFail("Unable to instantiate Data from rules.json")
            return
        }

        campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: campaignRulesCache, ruleEngine: ruleEngine)
        let campaignCachedRules = CampaignCachedRules(cacheable: data, lastModified: nil, eTag: nil)
        _ = campaignRulesCache.setCachedRules(rulesUrl: rulesJsonUrl.absoluteString, cachedRules: campaignCachedRules)

        //Action
        campaignRulesDownloader.loadRulesFromCache(rulesUrlString: rulesJsonUrl.absoluteString)

        //Verify
        XCTAssertTrue(mockDiskCache.isGetCacheCalled)
        XCTAssertTrue(ruleEngine.isReplaceRulesCalled)
        XCTAssertNotNil(ruleEngine.rules)
        XCTAssertEqual(ruleEngine.rules?.count, 5)
    }

    func testLoadRulesFromCacheFailure() {
        //Setup
        let invalidUrl = "https://fakeurl.com"
        campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: campaignRulesCache, ruleEngine: ruleEngine)

        //Action
        campaignRulesDownloader.loadRulesFromCache(rulesUrlString: invalidUrl)

        //Verify
        XCTAssertTrue(mockDiskCache.isGetCacheCalled)
        XCTAssertFalse(ruleEngine.isReplaceRulesCalled)
    }

    func testLoadRulesFromUrlNetworkRequestContainsLinkageField() {
        //Setup
        guard let url = URL(string: "https://testurl.com") else {
            XCTFail("Unable to form test URL")
            return
        }

        let linkageField = "testLinkageField"
        //Encode Linkage field String to Base64
        let data = linkageField.data(using: .utf8)
        guard let linkageFieldBase64Encoded = data?.base64EncodedString() else {
            XCTFail("Unable to encode linkage filed to Base64")
            return
        }
        campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: campaignRulesCache, ruleEngine: ruleEngine)
        let linkageFields = [
            CampaignConstants.Campaign.LINKAGE_FIELD_NETWORK_HEADER: linkageFieldBase64Encoded
        ]

        //Action
        campaignRulesDownloader.loadRulesFromUrl(rulesUrl: url, linkageFieldHeaders: linkageFields, state: CampaignState())

        //Assert
        XCTAssertTrue(mockNetworking.connectAsyncCalled)
        let linkageFieldHeaderReceived = mockNetworking.cachedNetworkRequests[mockNetworking.cachedNetworkRequests.count - 1].httpHeaders[CampaignConstants.Campaign.LINKAGE_FIELD_NETWORK_HEADER]
        XCTAssertEqual(linkageFieldHeaderReceived, linkageFieldBase64Encoded)
    }

    func testLoadRulesFromUrlNetworkRequestContainsLastModifiedAndETagHeaders() {
        //Setup
        guard let url = URL(string: "https://testurl.com") else {
            XCTFail("Unable to form test URL")
            return
        }
        guard let rulesJsonUrl = Self.campaignRulesJsonUrl else {
            XCTFail("rules.json URL is nil")
            return
        }

        guard let data = try? Data(contentsOf: rulesJsonUrl) else {
            XCTFail("Unable to instantiate Data from rules.json")
            return
        }

        let eTag = "fakeETag"
        let lastModified = Date().description
        let campaignCachedRules = CampaignCachedRules(cacheable: data, lastModified: lastModified, eTag: eTag)
        campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: campaignRulesCache, ruleEngine: ruleEngine)
        _ = campaignRulesCache.setCachedRules(rulesUrl: url.absoluteString, cachedRules: campaignCachedRules)

        //Action
        campaignRulesDownloader.loadRulesFromUrl(rulesUrl: url, linkageFieldHeaders: nil, state: CampaignState())

        //Assert
        XCTAssertTrue(mockNetworking.connectAsyncCalled)
        let headers = mockNetworking.cachedNetworkRequests[mockNetworking.cachedNetworkRequests.count - 1].httpHeaders
        XCTAssertEqual(headers[NetworkServiceConstants.Headers.IF_NONE_MATCH], eTag)
        XCTAssertEqual(headers[NetworkServiceConstants.Headers.IF_MODIFIED_SINCE], lastModified)
    }

    func testLoadRulesFromUrlEtagNotModified() {
        //Setup
        guard let url = URL(string: "https://testurl.com") else {
            XCTFail("Unable to form test URL")
            return
        }

        let statusCode = 304 ///Etag not modified
        let httpUrlResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)

        let httpConnection = HttpConnection(data: nil, response: httpUrlResponse, error: nil)
        mockNetworking.expectedResponse = httpConnection

        campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: campaignRulesCache, ruleEngine: ruleEngine)

        //Action
        campaignRulesDownloader.loadRulesFromUrl(rulesUrl: url, linkageFieldHeaders: nil, state: CampaignState())

        //Assert
        XCTAssertTrue(mockNetworking.connectAsyncCalled)
        XCTAssertFalse(ruleEngine.isReplaceRulesCalled)
    }

    func testLoadRulesFromUrlResponseDataIsNil() {
        //Setup
        guard let url = URL(string: "https://testurl.com") else {
            XCTFail("Unable to form test URL")
            return
        }

        guard let rulesJsonUrl = Self.campaignRulesJsonUrl else {
            XCTFail("rules.json URL is nil")
            return
        }

        guard let data = try? Data(contentsOf: rulesJsonUrl) else {
            XCTFail("Unable to instantiate Data from rules.json")
            return
        }

        let eTag = "fakeETag"
        let lastModified = Date().description
        let campaignCachedRules = CampaignCachedRules(cacheable: data, lastModified: lastModified, eTag: eTag)
        campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: campaignRulesCache, ruleEngine: ruleEngine)
        _ = campaignRulesCache.setCachedRules(rulesUrl: url.absoluteString, cachedRules: campaignCachedRules)
        mockNetworking.expectedResponse = createHttpConnection(statusCode: 200, url: url, data: nil, error: nil)

        //Action
        campaignRulesDownloader.loadRulesFromUrl(rulesUrl: url, linkageFieldHeaders: nil, state: CampaignState())

        //Assert
        XCTAssertTrue(mockNetworking.connectAsyncCalled)
        XCTAssertFalse(ruleEngine.isReplaceRulesCalled)
    }

    func testLoadRulesFromUrlSuccessTriggersRulesCaching() {
        //Setup
        guard let url = URL(string: "https://testurl.com") else {
            XCTFail("Unable to form test URL")
            return
        }

        guard let rulesJsonUrl = Self.campaignRulesJsonUrl else {
            XCTFail("rules.json URL is nil")
            return
        }

        guard let dataJson = try? Data(contentsOf: rulesJsonUrl) else {
            XCTFail("Unable to instantiate Data from rules.json")
            return
        }

        guard let rulesZipUrl = Self.campaignRulesZipUrl else {
            XCTFail("rules.zip URL is nil")
            return
        }

        guard let dataZip = try? Data(contentsOf: rulesZipUrl) else {
            XCTFail("Unable to instantiate Data from rules.zip")
            return
        }

        let dispatchQueue = DispatchQueue(label: "CampaignTestDispatchQueue")

        let campaignCachedRules = CampaignCachedRules(cacheable: dataJson, lastModified: nil, eTag: nil)
        campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: campaignRulesCache, ruleEngine: ruleEngine, dispatchQueue: dispatchQueue)
        _ = campaignRulesCache.setCachedRules(rulesUrl: url.absoluteString, cachedRules: campaignCachedRules)
        mockNetworking.expectedResponse = createHttpConnection(statusCode: 200, url: url, data: dataZip)

        mockDiskCache.reset()

        //Action
        campaignRulesDownloader.loadRulesFromUrl(rulesUrl: url, linkageFieldHeaders: nil, state: CampaignState())

        Thread.sleep(forTimeInterval: 2)

        //Assert
        XCTAssertTrue(mockDiskCache.isSetCacheCalled)
        XCTAssertEqual(mockDiskCache.cache.count, 1)
    }

    func testLoadRulesFromUrlSuccessTriggersRulesLoadingInRulesEngine() {
        //Setup
        guard let url = URL(string: "https://testurl.com") else {
            XCTFail("Unable to form test URL")
            return
        }

        guard let rulesJsonUrl = Self.campaignRulesJsonUrl else {
            XCTFail("rules.json URL is nil")
            return
        }

        guard let dataJson = try? Data(contentsOf: rulesJsonUrl) else {
            XCTFail("Unable to instantiate Data from rules.json")
            return
        }

        guard let rulesZipUrl = Self.campaignRulesZipUrl else {
            XCTFail("rules.zip URL is nil")
            return
        }

        guard let dataZip = try? Data(contentsOf: rulesZipUrl) else {
            XCTFail("Unable to instantiate Data from rules.zip")
            return
        }

        let dispatchQueue = DispatchQueue(label: "CampaignTestDispatchQueue")

        let campaignCachedRules = CampaignCachedRules(cacheable: dataJson, lastModified: nil, eTag: nil)
        campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: campaignRulesCache, ruleEngine: ruleEngine, dispatchQueue: dispatchQueue)
        _ = campaignRulesCache.setCachedRules(rulesUrl: url.absoluteString, cachedRules: campaignCachedRules)
        mockNetworking.expectedResponse = createHttpConnection(statusCode: 200, url: url, data: dataZip)

        //Action
        campaignRulesDownloader.loadRulesFromUrl(rulesUrl: url, linkageFieldHeaders: nil, state: CampaignState())

        Thread.sleep(forTimeInterval: 2)

        //Assert
        XCTAssertTrue(mockNetworking.connectAsyncCalled)
        XCTAssertTrue(ruleEngine.isReplaceRulesCalled)
        XCTAssertEqual(ruleEngine.rules?.count, 5)
    }

    func testLoadRulesFromUrlSuccessTriggersUrlCachingInDataStore() {
        //Setup
        guard let url = URL(string: "https://testurl.com") else {
            XCTFail("Unable to form test URL")
            return
        }

        guard let rulesJsonUrl = Self.campaignRulesJsonUrl else {
            XCTFail("rules.json URL is nil")
            return
        }

        guard let dataJson = try? Data(contentsOf: rulesJsonUrl) else {
            XCTFail("Unable to instantiate Data from rules.json")
            return
        }

        guard let rulesZipUrl = Self.campaignRulesZipUrl else {
            XCTFail("rules.zip URL is nil")
            return
        }

        guard let dataZip = try? Data(contentsOf: rulesZipUrl) else {
            XCTFail("Unable to instantiate Data from rules.zip")
            return
        }

        let dispatchQueue = DispatchQueue(label: "CampaignTestDispatchQueue")
        let campaignState = CampaignState()

        let campaignCachedRules = CampaignCachedRules(cacheable: dataJson, lastModified: nil, eTag: nil)
        campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: campaignRulesCache, ruleEngine: ruleEngine, dispatchQueue: dispatchQueue)
        _ = campaignRulesCache.setCachedRules(rulesUrl: url.absoluteString, cachedRules: campaignCachedRules)
        mockNetworking.expectedResponse = createHttpConnection(statusCode: 200, url: url, data: dataZip)

        //Action
        campaignRulesDownloader.loadRulesFromUrl(rulesUrl: url, linkageFieldHeaders: nil, state: campaignState)

        Thread.sleep(forTimeInterval: 1)

        //Assert
        XCTAssertTrue(campaignState.getRulesUrlFromDataStore()?.contains(url.absoluteString) ?? false)
    }

    func testLoadRulesFromUrlSuccessTriggersAssetsDownload() {
        //Setup
        guard let url = URL(string: "https://testurl.com") else {
            XCTFail("Unable to form test URL")
            return
        }

        guard let rulesJsonUrl = Self.campaignRulesJsonUrl else {
            XCTFail("rules.json URL is nil")
            return
        }

        guard let dataJson = try? Data(contentsOf: rulesJsonUrl) else {
            XCTFail("Unable to instantiate Data from rules.json")
            return
        }

        guard let rulesZipUrl = Self.campaignRulesZipUrl else {
            XCTFail("rules.zip URL is nil")
            return
        }

        guard let dataZip = try? Data(contentsOf: rulesZipUrl) else {
            XCTFail("Unable to instantiate Data from rules.zip")
            return
        }

        let assetURL = "https://homepages.cae.wisc.edu/~ece533/images/airplane.png"
        let dispatchQueue = DispatchQueue(label: "CampaignTestDispatchQueue")
        let campaignState = CampaignState()
        let campaignMessageAssetsCache = CampaignMessageAssetsCache()

        let campaignCachedRules = CampaignCachedRules(cacheable: dataJson, lastModified: nil, eTag: nil)
        campaignRulesDownloader = CampaignRulesDownloader(campaignRulesCache: campaignRulesCache, ruleEngine: ruleEngine, campaignMessageAssetsCache: campaignMessageAssetsCache, dispatchQueue: dispatchQueue)
        _ = campaignRulesCache.setCachedRules(rulesUrl: url.absoluteString, cachedRules: campaignCachedRules)
        mockNetworking.expectedResponse = createHttpConnection(statusCode: 200, url: url, data: dataZip)

        //Action
        campaignRulesDownloader.loadRulesFromUrl(rulesUrl: url, linkageFieldHeaders: nil, state: campaignState)

        Thread.sleep(forTimeInterval: 2)

        //Assert
        let networkRequests = mockNetworking.cachedNetworkRequests
        let imageDownloadRequest = networkRequests[networkRequests.count - 1]
        XCTAssertEqual(networkRequests.count, 2)
        XCTAssertEqual(imageDownloadRequest.url.absoluteString, assetURL)
    }
}

// MARK: Helper functions
extension CampaignRulesDownloaderTests {

    private func createHttpConnection(statusCode: Int, url: URL, httpVersion: String? = nil, headerFields: [String: String]? = nil, data: Data? = nil, error: Error? = nil) -> HttpConnection {
        let httpUrlResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: httpVersion, headerFields: headerFields)

        let httpConnection = HttpConnection(data: data, response: httpUrlResponse, error: error)
        return httpConnection
    }
}
