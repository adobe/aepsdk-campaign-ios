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
@testable import AEPIdentity
@testable import AEPLifecycle
import UIKit

class CampaignFunctionalTests: XCTestCase {
    var mockRuntime: TestableExtensionRuntime!
    var testableNetworkService: TestableNetworkService!
    var datastore: NamedCollectionDataStore!

    override func setUp() {
        NamedCollectionDataStore.clear()
        FileManager.default.clearCache()
        ServiceProvider.shared.reset()
        EventHub.reset()
        datastore = NamedCollectionDataStore(name: CampaignConstants.DATASTORE_NAME)
        mockRuntime = TestableExtensionRuntime()
        testableNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = testableNetworkService
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        sleep(2)
    }

    override func tearDown() {
        let unregisterExpectation = XCTestExpectation(description: "unregister extensions")
        unregisterExpectation.expectedFulfillmentCount = 3
        MobileCore.unregisterExtension(Campaign.self) {
            unregisterExpectation.fulfill()
        }

        MobileCore.unregisterExtension(Identity.self) {
            unregisterExpectation.fulfill()
        }

        MobileCore.unregisterExtension(Lifecycle.self) {
            unregisterExpectation.fulfill()
        }

        wait(for: [unregisterExpectation], timeout: 2)
    }

    func initExtensionsAndWait() {
        let initExpectation = XCTestExpectation(description: "init extensions")
        MobileCore.setLogLevel(.trace)
        MobileCore.registerExtensions([Campaign.self, Identity.self, Lifecycle.self]) {
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 2)
    }

    func updateConfiguration(customConfig: [String: Any]? = nil) {
        var configDict = [
            CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue,
            CampaignConstants.Configuration.GLOBAL_CONFIG_BUILD_ENVIRONMENT: "prod",
            CampaignConstants.Configuration.CAMPAIGN_MCIAS: "mcias-server.com",
            CampaignConstants.Configuration.PROPERTY_ID: "propertyId",
            CampaignConstants.Configuration.CAMPAIGN_PKEY: "pkey",
            CampaignConstants.Configuration.CAMPAIGN_SERVER: "prod.campaign.adobe.com",
            TestConstants.Configuration.ORG_ID: "testOrg@AdobeOrg",
            TestConstants.Configuration.LIFECYCLE_SESSION_TIMEOUT: 2,
            CampaignConstants.Configuration.CAMPAIGN_TIMEOUT: 5,
            CampaignConstants.Configuration.DEV_PKEY: "dev_pkey",
            CampaignConstants.Configuration.STAGE_PKEY: "stage_pkey",
            CampaignConstants.Configuration.DEV_CAMPAIGN_SERVER: "dev.campaign.adobe.com",
            CampaignConstants.Configuration.STAGE_CAMPAIGN_SERVER: "stage.campaign.adobe.com"
        ] as [String: Any]

        configDict.merge(customConfig ?? [:]) { _, newValue in
            newValue
        }

        MobileCore.updateConfigurationWith(configDict: configDict)
        sleep(1)
    }

    func getEcid() -> String {
        let expectation = XCTestExpectation(description: "valid ecid is retrieved.")
        var ecid = ""
        Identity.getExperienceCloudId { (retrievedEcid, _) in
            if let retrievedEcid = retrievedEcid, !retrievedEcid.isEmpty {
                ecid = retrievedEcid
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5)
        return ecid
    }

    func setBuildEnvironment(environment: String) {
        var config = [String: Any]()
        config[CampaignConstants.Configuration.GLOBAL_CONFIG_BUILD_ENVIRONMENT] = environment
        MobileCore.updateConfigurationWith(configDict: config)
        sleep(1)
    }

    func updateTimestampInDatastore(timestamp: Int) {
        datastore.set(key: CampaignConstants.Campaign.Datastore.REGISTRATION_TIMESTAMP_KEY, value: timestamp)
    }

    func updateEcidInDatastore(ecid: String) {
        datastore.set(key: CampaignConstants.Campaign.Datastore.ECID_KEY, value: ecid)
    }

    func clearLifecycleDataInDatastore() {
        FileManager.default.clearLifecycleData()
    }

    func setCampaignRulesFromBundleAsResponse(expectedUrlFragment: String, statusCode: Int, mockNetworkService: TestableNetworkService) {
        guard let rulesZip = Bundle.main.url(forResource: "rules-testing", withExtension: "zip") else {
            print("Failed to find rules zip in bundle.")
            return
        }
        guard let responseData = try? Data(contentsOf: rulesZip) else {
            print("Failed to convert the zipfile into data.")
            return
        }
        let response = HTTPURLResponse(url: URL(string: "https://adobe.com")!, statusCode: statusCode, httpVersion: nil, headerFields: [:])

        mockNetworkService.mock { _ in
            return (data: responseData, response: response, error: nil)
        }
    }

    // MARK: campaign registration tests
    func testCampaignProfileUpdateHappy() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()
        let ecid = getEcid()
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // verify
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. campaign registration request sent to prod environment
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyCampaignRegistrationRequest(request: requests[2], buildEnvironment: nil, ecid: ecid)
    }

    func testCampaignProfileUpdateWhenPrivacyIsOptedOut() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedOut.rawValue])
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // verify
        // 0 requests expected
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 0)
    }

    // MARK: environment aware config tests
    func testEnvironmentAwareConfigWithDevEnvironment() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.GLOBAL_CONFIG_BUILD_ENVIRONMENT: "dev"])
        let ecid = getEcid()
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // verify
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. campaign registration request sent to dev environment
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: "dev", ecid: ecid, isPersonalized: false)
        verifyCampaignRegistrationRequest(request: requests[2], buildEnvironment: "dev", ecid: ecid)
    }

    func testEnvironmentAwareConfigWithStageEnvironment() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.GLOBAL_CONFIG_BUILD_ENVIRONMENT: "stage"])
        let ecid = getEcid()
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // verify
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. campaign registration request sent to stage environment
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: "stage", ecid: ecid, isPersonalized: false)
        verifyCampaignRegistrationRequest(request: requests[2], buildEnvironment: "stage", ecid: ecid)
    }

    func testEnvironmentAwareConfigWithInvalidEnvironment() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.GLOBAL_CONFIG_BUILD_ENVIRONMENT: "invalid"])
        let ecid = getEcid()
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // verify
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. campaign registration request sent to prod environment due to invalid build environment
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyCampaignRegistrationRequest(request: requests[2], buildEnvironment: nil, ecid: ecid)
    }

    // MARK: setLinkageFields(...) and resetLinkageFields() tests
    func testSetLinkageFieldsHappy() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        let linkageFields = [
            "key": "value",
            "key2": "value2",
            "key3": "value3"
        ]
        Campaign.setLinkageFields(linkageFields)
        sleep(1)

        // verify
        let ecid = getEcid()
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. personalized campaign rules download with linkage fields header
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyCampaignRulesDownloadRequest(request: requests[2], buildEnvironment: nil, ecid: ecid, isPersonalized: true)
    }

    func testSetLinkageFieldsThenResetLinkageFields() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        let linkageFields = [
            "key": "value",
            "key2": "value2",
            "key3": "value3"
        ]
        Campaign.setLinkageFields(linkageFields)
        sleep(1)
        Campaign.resetLinkageFields()
        sleep(1)

        // verify
        let ecid = getEcid()
        // 4 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. personalized campaign rules download with linkage fields header
        // 4. 2nd non personalized campaign rules download
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 4)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyCampaignRulesDownloadRequest(request: requests[2], buildEnvironment: nil, ecid: ecid, isPersonalized: true)
        verifyCampaignRulesDownloadRequest(request: requests[3], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
    }

    func testSetLinkageFieldsWithEmptyLinkageFieldsDictionary() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        let linkageFields = [String: String]()
        Campaign.setLinkageFields(linkageFields)
        sleep(1)

        // verify
        let ecid = getEcid()
        // 2 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 2)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
    }

    func testSetLinkageFieldsWhenPrivacyOptedOut() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedOut.rawValue])

        // test
        let linkageFields = [
            "key": "value",
            "key2": "value2",
            "key3": "value3"
        ]
        Campaign.setLinkageFields(linkageFields)
        sleep(1)

        // verify
        // 0 requests expected:
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 0)
    }

    func testSetLinkageFieldsWhenPrivacyUnknown() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.unknown.rawValue])

        // test
        let linkageFields = [:] as [String: String]
        Campaign.setLinkageFields(linkageFields)
        sleep(1)

        // verify
        // 0 requests expected:
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 0)
        MobileCore.setPrivacyStatus(.optedIn)
        sleep(2)
    }

    // TODO: investigate, test is flaky
    func skip_testSetLinkageFieldsThenPrivacyOptOutAndPrivacyOptedInTriggersNonPersonalizedRulesDownload() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()
        let ecid = getEcid()
        // test
        let linkageFields = [
            "key": "value",
            "key2": "value2",
            "key3": "value3"
        ]
        Campaign.setLinkageFields(linkageFields)
        sleep(1)
        MobileCore.setPrivacyStatus(.optedOut)
        sleep(1)
        MobileCore.setPrivacyStatus(.optedIn)
        sleep(1)
        // verify
        // 6 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. personalized campaign rules download with linkage fields header
        // 4. demdex opt out hit with original mid
        // 5. 2nd demdex hit with new mid
        // 6. non personalized campaign rules download with new mid
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 6)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyCampaignRulesDownloadRequest(request: requests[2], buildEnvironment: nil, ecid: ecid, isPersonalized: true)
        verifyDemdexOptOutHit(request: requests[3], ecid: ecid)
        let newEcid = getEcid()
        verifyDemdexHit(request: requests[4], ecid: newEcid)
        verifyCampaignRulesDownloadRequest(request: requests[5], buildEnvironment: nil, ecid: newEcid, isPersonalized: false)
    }

    // MARK: notification tracking tests
    func testLocalNotificationImpressionTracking() {
        // setup
        setCampaignRulesFromBundleAsResponse(expectedUrlFragment: "https://mcias-server.com/mcias/", statusCode: 200, mockNetworkService: testableNetworkService)
        sleep(1)
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        MobileCore.track(action: "localImpression", data: nil)
        sleep(1)

        // verify
        let ecid = getEcid()
        // 5 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. remote asset download (due to rules zip containing fullscreen message with assets)
        // 4. local asset download (due to rules zip containing a fullscreen message with assets)
        // 5. local notification viewed track request
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 5)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        XCTAssertEqual("https://as2.ftcdn.net/v2/jpg/03/38/75/33/1000_F_338753339_GeGEgDtV1MR4tcoZLX3KbyJW40wqCY6J.jpg", requests[2].url.absoluteString)
        verifyAssetInCacheFor(url: requests[2].url.absoluteString)
        XCTAssertEqual("local.jpg", requests[3].url.absoluteString)
        verifyMessageTrackRequest(request: requests[4], ecid: ecid, interactionType: "7")
    }

    func testLocalNotificationImpressionTrackingViaCollectMessageInfo() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        var messageData = [String: Any]()
        messageData["broadlogId"] = "h153d80"
        messageData["deliveryId"] = "b670ea"
        messageData["action"] = "7"
        MobileCore.collectMessageInfo(messageData)
        sleep(1)

        // verify
        let ecid = getEcid()
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. local notification viewed track request
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyMessageTrackRequest(request: requests[2], ecid: ecid, interactionType: "7")
    }

    func testLocalNotificationOpenTracking() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        var messageData = [String: Any]()
        messageData["broadlogId"] = "h153d80"
        messageData["deliveryId"] = "b670ea"
        messageData["action"] = "1"
        MobileCore.collectMessageInfo(messageData)
        sleep(1)

        // verify
        let ecid = getEcid()
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. local notification opened track request
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyMessageTrackRequest(request: requests[2], ecid: ecid, interactionType: "1")
    }

    func testLocalNotificationClickTracking() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        var messageData = [String: Any]()
        messageData["broadlogId"] = "h153d80"
        messageData["deliveryId"] = "b670ea"
        messageData["action"] = "2"
        MobileCore.collectMessageInfo(messageData)
        sleep(1)

        // verify
        let ecid = getEcid()
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. local notification clicked track request
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyMessageTrackRequest(request: requests[2], ecid: ecid, interactionType: "2")
    }

    func testNotificationTrackingMissingBroadlogId() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        var messageData = [String: Any]()
        messageData["deliveryId"] = "b670ea"
        messageData["action"] = "2"
        MobileCore.collectMessageInfo(messageData)
        sleep(1)

        // verify
        let ecid = getEcid()
        // 2 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 2)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
    }

    func testNotificationTrackingMissingDeliveryId() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        var messageData = [String: Any]()
        messageData["broadlogId"] = "h153d80"
        messageData["action"] = "2"
        MobileCore.collectMessageInfo(messageData)
        sleep(1)

        // verify
        let ecid = getEcid()
        // 2 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 2)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
    }

    func testNotificationTrackingMissingAction() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        var messageData = [String: Any]()
        messageData["broadlogId"] = "h153d80"
        messageData["deliveryId"] = "b670ea"
        MobileCore.collectMessageInfo(messageData)
        sleep(1)

        // verify
        let ecid = getEcid()
        // 2 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 2)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
    }

    // MARK: fullscreen asset download tests
    func testVerifyFullscreenAssetsAreDownloadedAndCached() {
        // setup
        setCampaignRulesFromBundleAsResponse(expectedUrlFragment: "https://mcias-server.com/mcias/", statusCode: 200, mockNetworkService: testableNetworkService)
        sleep(1)
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()

        // test
        MobileCore.track(action: "fullscreen", data: nil)
        sleep(1)

        // verify
        let ecid = getEcid()
        // 4 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. remote asset download (as well as verify assets are cached for the remote asset)
        // 4. local asset download
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 4)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        XCTAssertEqual("https://as2.ftcdn.net/v2/jpg/03/38/75/33/1000_F_338753339_GeGEgDtV1MR4tcoZLX3KbyJW40wqCY6J.jpg", requests[2].url.absoluteString)
        verifyAssetInCacheFor(url: requests[2].url.absoluteString)
        XCTAssertEqual("local.jpg", requests[3].url.absoluteString)
    }

    // MARK: registration reduction tests
    func testVerifyNoProfileUpdateOnSecondLifecycleLaunchWithDefaultRegistrationDelay() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()
        let ecid = getEcid()
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // wait for lifecycle session timeout
        usleep(2500)
        MobileCore.lifecycleStart(additionalContextData: nil)
        // verify
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. campaign registration request sent to prod environment
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyCampaignRegistrationRequest(request: requests[2], buildEnvironment: nil, ecid: ecid)
    }

    func testVerifyProfileUpdateOnSecondLifecycleLaunchWithDefaultRegistrationDelayElapsed() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        self.updateConfiguration()
        // simulate a successful registration 8 days in the past + add the retrieved ecid to the datastore
        let timestamp = Int(Date().timeIntervalSince1970) - (8 * CampaignConstants.Campaign.SECONDS_IN_A_DAY)
        updateTimestampInDatastore(timestamp: timestamp)
        let ecid = getEcid()
        updateEcidInDatastore(ecid: ecid)
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // verify
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. campaign registration request sent to prod environment
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyCampaignRegistrationRequest(request: requests[2], buildEnvironment: nil, ecid: ecid)
    }

    func testVerifyProfileUpdateOnSecondLifecycleLaunchWithCustomRegistrationDelayElapsed() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        // set a registration delay of 30 days
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_DELAY_KEY: 30, CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_PAUSED_KEY: false])
        // simulate a successful registration 31 days in the past + add the retrieved ecid to the datastore
        let timestamp = Int(Date().timeIntervalSince1970) - (31 * CampaignConstants.Campaign.SECONDS_IN_A_DAY)
        updateTimestampInDatastore(timestamp: timestamp)
        let ecid = getEcid()
        updateEcidInDatastore(ecid: ecid)
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // verify
        // 3 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. campaign registration request sent to prod environment
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 3)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyCampaignRegistrationRequest(request: requests[2], buildEnvironment: nil, ecid: ecid)
    }

    func testVerifyNoProfileUpdateOnSecondLifecycleLaunchWithCustomRegistrationDelayNotElapsed() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        // set a registration delay of 100 days
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_DELAY_KEY: 100, CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_PAUSED_KEY: false])
        // simulate a successful registration 31 days in the past + add the retrieved ecid to the datastore
        let timestamp = Int(Date().timeIntervalSince1970) - (31 * CampaignConstants.Campaign.SECONDS_IN_A_DAY)
        updateTimestampInDatastore(timestamp: timestamp)
        let ecid = getEcid()
        updateEcidInDatastore(ecid: ecid)
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // verify
        // 2 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 2)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
    }

    func testVerifyNoProfileUpdateOnLifecycleLaunchWhenRegistrationIsPaused() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        // pause campaign registration requests
        self.updateConfiguration(customConfig: [ CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_PAUSED_KEY: true])
        let ecid = getEcid()
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // verify
        // 2 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 2)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
    }

    func testVerifyProfileUpdateOnSecondLifecycleLaunchWhenRegistrationDelaySetToZero() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        // set a registration delay of 0 days. a registration request will be sent on every launch.
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_DELAY_KEY: 0, CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_PAUSED_KEY: false])
        let ecid = getEcid()
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        MobileCore.lifecyclePause()
        sleep(3)
        MobileCore.lifecycleStart(additionalContextData: nil)
        sleep(1)
        // verify
        // 4 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. first campaign registration request sent to prod environment
        // 4. second campaign registration request sent to prod environment
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 4)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyCampaignRegistrationRequest(request: requests[2], buildEnvironment: nil, ecid: ecid)
        verifyCampaignRegistrationRequest(request: requests[3], buildEnvironment: nil, ecid: ecid)
    }
}
