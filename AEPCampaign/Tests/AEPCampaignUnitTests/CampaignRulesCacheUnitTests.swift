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
import AEPServices
@testable import AEPCampaign

class CampaignRulesCacheUnitTests: XCTestCase {

    var mockDiskcache: MockDiskCache!
    var campaignRulesCache: CampaignRulesCache!
    
    static var bundle: Bundle {
        Bundle(for: self)
    }

    static var campaignRulesJsonUrl: URL? {
        bundle.url(forResource: "rules", withExtension: ".json")
    }
    
    static var rulesData: Data? {
        guard let url = campaignRulesJsonUrl else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    override func setUp() {
        campaignRulesCache = CampaignRulesCache()
        mockDiskcache = MockDiskCache()
        ServiceProvider.shared.cacheService = mockDiskcache
    }
    
    func testSetCacheRulesSuccess() {
        //Setup
        guard let rulesUrl = Self.campaignRulesJsonUrl else {
            XCTFail("Unable to retrieve bundled rules.json URL")
            return
        }
        guard let rulesData = Self.rulesData else {
            XCTFail("Unable to create Data from rules.json")
            return
        }
        let campaignCachedRules = CampaignCachedRules(cacheable: rulesData, lastModified: nil, eTag: nil)
        
        //Action
        let hasSuccessfullyCachedRules = campaignRulesCache.setCachedRules(rulesUrl: rulesUrl.absoluteString, cachedRules: campaignCachedRules)
        
        //Assert
        XCTAssertTrue(hasSuccessfullyCachedRules)
    }
    
    func testGetCacheRulesSuccess() {
        //Setup
        guard let rulesUrl = Self.campaignRulesJsonUrl else {
            XCTFail("Unable to retrieve bundled rules.json URL")
            return
        }
        
        guard let rulesData = Self.rulesData else {
            XCTFail("Unable to create Data from rules.json")
            return
        }
        let campaignCachedRules = CampaignCachedRules(cacheable: rulesData, lastModified: nil, eTag: nil)
        
        //Action
        let hasSuccessfullyCachedRules = campaignRulesCache.setCachedRules(rulesUrl: rulesUrl.absoluteString, cachedRules: campaignCachedRules)
        let retrievedCampaignCachedRule = campaignRulesCache.getCachedRules(rulesUrl: rulesUrl.absoluteString)
        
        //Assert
        XCTAssertTrue(hasSuccessfullyCachedRules)
        XCTAssertNotNil(retrievedCampaignCachedRule)
    }
    
    func testGetCacheRulesFailure() {
        //Setup
        guard let rulesUrl = Self.campaignRulesJsonUrl else {
            XCTFail("Unable to retrieve bundled rules.json URL")
            return
        }
        guard let rulesData = Self.rulesData else {
            XCTFail("Unable to create Data from rules.json")
            return
        }
        let campaignCachedRules = CampaignCachedRules(cacheable: rulesData, lastModified: nil, eTag: nil)
        
        //Action
        let hasSuccessfullyCachedRules = campaignRulesCache.setCachedRules(rulesUrl: rulesUrl.absoluteString, cachedRules: campaignCachedRules)
        
        let invalidUrl = "\(rulesUrl.absoluteString) invalid string"
        let retrievedCampaignCachedRule = campaignRulesCache.getCachedRules(rulesUrl: invalidUrl)
        
        //Assert
        XCTAssertTrue(hasSuccessfullyCachedRules)
        XCTAssertNil(retrievedCampaignCachedRule)        
    }
    
    func testDeleteCacheRuleSuccess() {
        //Setup
        guard let rulesUrl = Self.campaignRulesJsonUrl else {
            XCTFail("Unable to retrieve bundled rules.json URL")
            return
        }
        guard let rulesData = Self.rulesData else {
            XCTFail("Unable to create Data from rules.json")
            return
        }
        let campaignCachedRules = CampaignCachedRules(cacheable: rulesData, lastModified: nil, eTag: nil)
        
        //Action
        let hasSuccessfullyCachedRules = campaignRulesCache.setCachedRules(rulesUrl: rulesUrl.absoluteString, cachedRules: campaignCachedRules)
        campaignRulesCache.deleteCachedRules(url: rulesUrl.absoluteString)
        
        let retrievedCampaignCachedRule = campaignRulesCache.getCachedRules(rulesUrl: rulesUrl.absoluteString)
        
        //Assert
        XCTAssertTrue(hasSuccessfullyCachedRules)
        XCTAssertNil(retrievedCampaignCachedRule)
    }
    
    func testDeleteCacheRuleFailure() {
        //Setup
        guard let rulesUrl = Self.campaignRulesJsonUrl else {
            XCTFail("Unable to retrieve bundled rules.json URL")
            return
        }
        guard let rulesData = Self.rulesData else {
            XCTFail("Unable to create Data from rules.json")
            return
        }
        let campaignCachedRules = CampaignCachedRules(cacheable: rulesData, lastModified: nil, eTag: nil)
        
        //Action
        let hasSuccessfullyCachedRules = campaignRulesCache.setCachedRules(rulesUrl: rulesUrl.absoluteString, cachedRules: campaignCachedRules)
        
        let invalidUrl = "\(rulesUrl.absoluteString) invalid string"
        campaignRulesCache.deleteCachedRules(url: invalidUrl)
        
        let retrievedCampaignCachedRule = campaignRulesCache.getCachedRules(rulesUrl: rulesUrl.absoluteString)
        
        //Assert
        XCTAssertTrue(hasSuccessfullyCachedRules)
        XCTAssertNotNil(retrievedCampaignCachedRule)
    }
    
    func testDeleteCachedAssets() {
        //Setup
        let fileManager = MockFileManager()
        guard let cacheDir = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return
        }
        let cachedAssetsUrl = cacheDir.appendingPathComponent(CampaignConstants.RulesDownloaderConstants.RULES_CACHE_DIRECTORY)
        try? fileManager.createDirectory(at: cachedAssetsUrl, withIntermediateDirectories: true, attributes: nil)
        let assetsDirectoryCreated = fileManager.fileExists(atPath: cachedAssetsUrl.absoluteString)
        
        //Action
        campaignRulesCache.deleteCachedAssets(fileManager: fileManager)
        
        //Assets
        XCTAssertTrue(assetsDirectoryCreated)
        XCTAssertFalse(fileManager.fileExists(atPath: cachedAssetsUrl.absoluteString))
    }
}
