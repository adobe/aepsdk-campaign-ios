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
import AEPServices

class MockDiskCache: Caching {
    var cache = [String: CacheEntry]()
    var isSetCacheCalled = false
    var isGetCacheCalled = false
    var isRemoveCacheItemCalled = false    

    func set(cacheName: String, key: String, entry: CacheEntry) throws {
        isSetCacheCalled = true
        cache[key] = entry
    }

    func get(cacheName: String, key: String) -> CacheEntry? {
        isGetCacheCalled = true
        return cache[key]
    }

    func remove(cacheName: String, key: String) throws {
        isRemoveCacheItemCalled = true
        cache.removeValue(forKey: key)
    }

    func reset() {
        cache = [String: CacheEntry]()
        isSetCacheCalled = false
        isGetCacheCalled = false
        isRemoveCacheItemCalled = false        
    }
}
