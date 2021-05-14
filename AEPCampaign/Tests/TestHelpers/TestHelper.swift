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

extension EventHub {
    static func reset() {
        shared = EventHub()
    }
}

extension UserDefaults {
    public static func clear() {
        for _ in 0 ... 5 {
            for key in UserDefaults.standard.dictionaryRepresentation().keys {
                UserDefaults.standard.removeObject(forKey: key)
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
        }
    }
}

extension XCTest {
    func verifyCampaignResponseEvent(expectedParameters: [String: Any]) {
        let event = expectedParameters["event"] as? Event
        let actionType = expectedParameters["actionType"] as? String ?? ""
        let expectedDataSize = expectedParameters["size"] as? Int ?? 0

        XCTAssertEqual(event?.name, "DataForMessageRequest")
        XCTAssertEqual(event?.type, EventType.campaign)
        XCTAssertEqual(event?.source, EventSource.responseContent)
        let data = event?.data as? [String: String] ?? [:]
        XCTAssertEqual(data.count, expectedDataSize)
        XCTAssertEqual(data["messageId"], "20761932")
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
}

extension String {
    ///Removes non alphanumeric character from `String`
    var alphanumeric: String {
        return components(separatedBy: CharacterSet.alphanumerics.inverted).joined().lowercased()
    }
}
