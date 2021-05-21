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

extension FileManager {

    ///Deletes all the cached files in folder `parentFolder` except the ones in `except` array.
    /// - Parameters:
    ///   - except: `Array` of the file names that doesn't have to be deleted.
    ///   - parentFolderRelativeToCache: Path of parent folder relative to Cache folder.
    func deleteCachedFiles(except filesToRetain: [String], parentFolderRelativeToCache: String) {
        guard var cacheDir = try? url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return
        }
        cacheDir.appendPathComponent(parentFolderRelativeToCache)
        guard let cachedFiles = try? contentsOfDirectory(atPath: cacheDir.absoluteString) else {
            return
        }
        let assetsToDelete = cachedFiles.filter { cachedFile in
            !filesToRetain.contains(cachedFile)
        }

        // MARK: Delete non required cached files for the message
        assetsToDelete.forEach { fileName in
            try? removeItem(atPath: "\(cacheDir.absoluteString)/\(fileName)")            
        }
    }
}
