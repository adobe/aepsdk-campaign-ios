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
    let datastore = NamedCollectionDataStore(name: CampaignConstants.DATASTORE_NAME)

    func waitForProcessing(interval: TimeInterval = 1) {
        let expectation = XCTestExpectation()
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + interval - 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: interval)
    }

    override func setUp() {
        UserDefaults.clear()
        FileManager.default.clearCache()
        ServiceProvider.shared.reset()
        EventHub.reset()
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

    func updateConfiguration(customConfig: [String: String]? = nil) {
        var configDict = [
            CampaignConstants.Configuration.GLOBAL_CONFIG_PRIVACY: "optedin",
            CampaignConstants.Configuration.GLOBAL_CONFIG_BUILD_ENVIRONMENT: "prod",
            CampaignConstants.Configuration.CAMPAIGN_MCIAS: "mcias-server.com",
            CampaignConstants.Configuration.PROPERTY_ID: "propertyId",
            CampaignConstants.Configuration.CAMPAIGN_PKEY: "pkey",
            CampaignConstants.Configuration.CAMPAIGN_SERVER: "prod.campaign.adobe.com",
            "experienceCloud.org": "testOrg@AdobeOrg",
            CampaignConstants.Configuration.CAMPAIGN_TIMEOUT: "5",
            CampaignConstants.Configuration.DEV_PKEY: "dev_pkey",
            CampaignConstants.Configuration.STAGE_PKEY: "stage_pkey",
            CampaignConstants.Configuration.DEV_CAMPAIGN_SERVER: "dev.campaign.adobe.com",
            CampaignConstants.Configuration.STAGE_CAMPAIGN_SERVER: "stage.campaign.adobe.com"
        ]

        configDict.merge(customConfig ?? [:]) { _, newValue in
            newValue
        }

        MobileCore.updateConfigurationWith(configDict: configDict)
        sleep(1)
    }

    func getEcid() -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var ecid = String()
        Identity.getExperienceCloudId { (retrievedEcid, _) in
            ecid = retrievedEcid ?? ""
            semaphore.signal()
        }
        semaphore.wait()
        return ecid
    }

    func setBuildEnvironment(environment: String) {
        var config = [String: Any]()
        config[CampaignConstants.Configuration.GLOBAL_CONFIG_BUILD_ENVIRONMENT] = environment
        MobileCore.updateConfigurationWith(configDict: config)
        waitForProcessing()
    }

    func setRegistrationDelayOrRegistrationPaused(delay: Int, pausedStatus: Bool) {
        var config = [String: Any]()
        config[CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_DELAY_KEY] = delay
        config[CampaignConstants.Configuration.CAMPAIGN_REGISTRATION_PAUSED_KEY] = pausedStatus
        MobileCore.updateConfigurationWith(configDict: config)
        waitForProcessing()
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

    // MARK: environment aware config tests
    func testEnvironmentAwareConfigWithDevEnvironment() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        let testableNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = testableNetworkService
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.GLOBAL_CONFIG_BUILD_ENVIRONMENT: "dev"])
        let ecid = getEcid()
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        waitForProcessing()
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
        let testableNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = testableNetworkService
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.GLOBAL_CONFIG_BUILD_ENVIRONMENT: "stage"])
        let ecid = getEcid()
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        waitForProcessing()
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
        let testableNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = testableNetworkService
        self.updateConfiguration(customConfig: [CampaignConstants.Configuration.GLOBAL_CONFIG_BUILD_ENVIRONMENT: "invalid"])
        let ecid = getEcid()
        // test
        MobileCore.lifecycleStart(additionalContextData: nil)
        waitForProcessing()
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
        let testableNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = testableNetworkService
        self.updateConfiguration()

        // test
        let linkageFields = [
            "key": "value",
            "key2": "value2",
            "key3": "value3"
        ]
        Campaign.setLinkageFields(linkageFields: linkageFields)
        waitForProcessing()

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
        let testableNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = testableNetworkService
        self.updateConfiguration()

        // test
        let linkageFields = [
            "key": "value",
            "key2": "value2",
            "key3": "value3"
        ]
        Campaign.setLinkageFields(linkageFields: linkageFields)
        waitForProcessing()
        Campaign.resetLinkageFields()
        waitForProcessing()

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
        let testableNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = testableNetworkService
        self.updateConfiguration()

        // test
        let linkageFields = [:] as [String: String]
        Campaign.setLinkageFields(linkageFields: linkageFields)
        waitForProcessing()

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

    // TODO: revisit, issue opened: https://github.com/adobe/aepsdk-core-ios/issues/639
    func skip_testSetLinkageFieldsThenPrivacyOptOutAndPrivacyOptedInTriggersNonPersonalizedRulesDownloadAgain() {
        // setup
        initExtensionsAndWait()
        sleep(1)
        let testableNetworkService = TestableNetworkService()
        ServiceProvider.shared.networkService = testableNetworkService
        self.updateConfiguration()

        // test
        let linkageFields = [
            "key": "value",
            "key2": "value2",
            "key3": "value3"
        ]
        Campaign.setLinkageFields(linkageFields: linkageFields)
        waitForProcessing()
        MobileCore.setPrivacyStatus(.optedOut)
        waitForProcessing()
        MobileCore.setPrivacyStatus(.optedIn)
        waitForProcessing()
        // verify
        let ecid = getEcid()
        // 6 requests expected:
        // 1. demdex hit
        // 2. non personalized campaign rules download
        // 3. personalized campaign rules download with linkage fields header
        // 4. demdex opt out hit
        // 5. 2nd demdex hit with new mid
        // 6. non personalized campaign rules download
        let requests = testableNetworkService.requests
        XCTAssertEqual(requests.count, 5)
        verifyDemdexHit(request: requests[0], ecid: ecid)
        verifyCampaignRulesDownloadRequest(request: requests[1], buildEnvironment: nil, ecid: ecid, isPersonalized: false)
        verifyCampaignRulesDownloadRequest(request: requests[2], buildEnvironment: nil, ecid: ecid, isPersonalized: true)
        let newEcid = getEcid()
        verifyDemdexHit(request: requests[4], ecid: newEcid)
        verifyCampaignRulesDownloadRequest(request: requests[5], buildEnvironment: nil, ecid: newEcid, isPersonalized: false)
    }
}
