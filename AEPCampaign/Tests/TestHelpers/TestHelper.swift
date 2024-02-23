/*
 Copyright 2020 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import XCTest
@testable import AEPCore
@testable import AEPServices
@testable import AEPCampaign
import AEPTestUtils

extension EventHub {
    static func reset() {
        shared = EventHub()
    }
}

extension NamedCollectionDataStore {
    static func clear(appGroup: String? = nil) {
        if let appGroup = appGroup, !appGroup.isEmpty {
            guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.appendingPathComponent("com.adobe.aep.datastore", isDirectory: true).path else {
                return
            }
            guard let filePaths = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
                return
            }
            for filePath in filePaths {
                try? FileManager.default.removeItem(atPath: directory + "/" + filePath)
            }
        } else {
            let directory = FileManager.default.urls(for: .libraryDirectory, in: .allDomainsMask)[0].appendingPathComponent("com.adobe.aep.datastore", isDirectory: true).path
            guard let filePaths = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
                return
            }
            for filePath in filePaths {
                try? FileManager.default.removeItem(atPath: directory + "/" + filePath)
            }
        }
    }
}

extension FileManager {
    func clearCache() {
        if let _ = self.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                try self.removeItem(at: URL(fileURLWithPath: "Library/Caches/com.adobe.module.identity"))
            } catch {
                print("ERROR DESCRIPTION: \(error)")
            }

            do {
                try self.removeItem(at: URL(fileURLWithPath: "Library/Caches/com.adobe.module.campaign"))
            } catch {
                print("ERROR DESCRIPTION: \(error)")
            }

            do {
                try self.removeItem(at: URL(fileURLWithPath: "Library/Caches/com.adobe.module.lifecycle"))
            } catch {
                print("ERROR DESCRIPTION: \(error)")
            }
        }
    }

    func clearLifecycleData() {
        if let _ = self.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                try self.removeItem(at: URL(fileURLWithPath: "Library/Caches/com.adobe.module.lifecycle"))
            } catch {
                print("ERROR DESCRIPTION: \(error)")
            }
        }
    }
}

extension XCTestCase: AnyCodableAsserts {
    func verifyCampaignResponseEvent(expectedParameters: [String: Any]) {
        let event = expectedParameters["event"] as? Event
        let actionType = expectedParameters["actionType"] as? String ?? ""
        let expectedDataSize = expectedParameters["size"] as? Int ?? 0

        XCTAssertEqual(event?.name, "DataForMessageRequest")
        XCTAssertEqual(event?.type, EventType.campaign)
        XCTAssertEqual(event?.source, EventSource.responseContent)
        let data = event?.data as? [String: String] ?? [:]
        XCTAssertEqual(data.count, expectedDataSize)
        XCTAssertEqual(data["a.message.id"], "20761932")
        XCTAssertEqual(data["a.message.\(actionType)"], "1")
        if let additionalData = expectedParameters["additionalData"] as? [String: String] {
            for (key, value) in additionalData {
                XCTAssertEqual(data[key], value)
            }
        }
        if data["type"] != nil && data["id"] != nil { // check for id and type fields if present
            let urlComponents = expectedParameters["expectedComponents"] as? [String] ?? []
            XCTAssertEqual(data["type"], urlComponents[0])
            XCTAssertEqual(data["id"], urlComponents[1])
        }
    }

    func verifyGenericDataOsEvent(event: Event?) {
        XCTAssertEqual(event?.name, "InternalGenericDataEvent")
        XCTAssertEqual(event?.type, EventType.genericData)
        XCTAssertEqual(event?.source, EventSource.os)
        let data = event?.data as? [String: String] ?? [:]
        XCTAssertEqual(data.count, 3)
        XCTAssertEqual(data["action"], "7")
        XCTAssertEqual(data["deliveryId"], "13ccd4c")
        XCTAssertEqual(data["broadlogId"], "h1bd500")
    }

    func verifyCampaignRegistrationRequest(request: NetworkRequest, buildEnvironment: String?, ecid: String) {
        let buildEnvironment = buildEnvironment ?? ""
        let url = request.url.absoluteString
        let payload = request.payloadAsDictionary()
        if !buildEnvironment.isEmpty {
            XCTAssertEqual("https://\(buildEnvironment).campaign.adobe.com/rest/head/mobileAppV5/\(buildEnvironment)_pkey/subscriptions/\(ecid)", url)
        } else {
            XCTAssertEqual("https://prod.campaign.adobe.com/rest/head/mobileAppV5/pkey/subscriptions/\(ecid)", url)
        }
        XCTAssertEqual(2, payload.count)
        XCTAssertEqual(ecid, payload["marketingCloudId"])
        XCTAssertEqual("apns", payload["pushPlatform"])
    }

    func verifyDemdexHit(request: NetworkRequest, ecid: String) {
        let url = request.url.absoluteString
        XCTAssertEqual(url, "https://dpm.demdex.net/id?d_rtbd=json&d_ver=2&d_orgid=testOrg@AdobeOrg&d_mid=\(ecid)")
    }

    func verifyDemdexOptOutHit(request: NetworkRequest, ecid: String) {
        let url = request.url.absoluteString
        XCTAssertEqual(url, "https://dpm.demdex.net/demoptout.jpg?d_orgid=testOrg@AdobeOrg&d_mid=\(ecid)")
    }

    func verifyAssetInCacheFor(url: String) {
        let expectation = XCTestExpectation(description: "cached asset exists in the message cache directory.")
        let fileManager = FileManager.default
        guard var cacheDir = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            XCTFail("the message cache directory does not exist")
            return
        }
        let expectedUrl = url.alphanumeric
        cacheDir.appendPathComponent("\(CampaignConstants.RulesDownloaderConstants.MESSAGE_CACHE_FOLDER)/56785213/\(expectedUrl)")
        if !fileManager.fileExists(atPath: cacheDir.path) {
            XCTFail("the cached message asset does not exist.")
            return
        }
        print("asset found at \(cacheDir.path)")
        expectation.fulfill()
        wait(for: [expectation], timeout: 5)
    }

    func verifyCampaignRulesDownloadRequest(request: NetworkRequest, buildEnvironment: String?, ecid: String, isPersonalized: Bool) {
        let expectedLinkageFieldsData = Data(base64Encoded: "eyJrZXkiOiJ2YWx1ZSIsImtleTMiOiJ2YWx1ZTMiLCJrZXkyIjoidmFsdWUyIn0=".data(using: .utf8)!)
        let expectedLinkageFieldsString = String(data: expectedLinkageFieldsData ?? Data(), encoding: .utf8)
        
        let buildEnvironment = buildEnvironment ?? ""
        let url = request.url.absoluteString
        let headers = request.httpHeaders
        XCTAssertFalse(headers.isEmpty)
        let xInAppAuthHeader = headers["X-InApp-Auth"] ?? "fail"
        let actualLinkageFieldsData = Data(base64Encoded: xInAppAuthHeader.data(using: .utf8)!)
        let actualLinkageFieldsString = String(data: actualLinkageFieldsData ?? Data(), encoding: .utf8)
        
        if !buildEnvironment.isEmpty {
            XCTAssertEqual(url, "https://mcias-server.com/mcias/\(buildEnvironment).campaign.adobe.com/propertyId/\(ecid)/rules.zip")
        } else {
            XCTAssertEqual(url, "https://mcias-server.com/mcias/prod.campaign.adobe.com/propertyId/\(ecid)/rules.zip")
        }
        if isPersonalized {
            XCTAssertNotNil(actualLinkageFieldsString)
            assertExactMatch(expected: expectedLinkageFieldsString.toAnyCodable()!, actual: actualLinkageFieldsString.toAnyCodable(), pathOptions: [])
        } else {
            XCTAssertNil(headers["X-InApp-Auth"])
        }
    }

    func verifyMessageTrackRequest(request: NetworkRequest, ecid: String, interactionType: String) {
        let url = request.url.absoluteString
        XCTAssertEqual(url, "https://prod.campaign.adobe.com/r/?id=h153d80,b670ea,\(interactionType)&mcId=\(ecid)")
    }
}

extension String {
    /// Removes non alphanumeric character from `String`
    var alphanumeric: String {
        return components(separatedBy: CharacterSet.alphanumerics.inverted).joined().lowercased()
    }
}

extension NetworkRequest {
    func payloadAsString() -> String {
        return String(data: connectPayload, encoding: .utf8) ?? ""
    }

    func payloadAsDictionary() -> [String: String] {
        guard let payload = try? JSONSerialization.jsonObject(with: self.connectPayload, options: .allowFragments) as? [String: String] else {
            return [:]
        }
        return payload
    }
}
