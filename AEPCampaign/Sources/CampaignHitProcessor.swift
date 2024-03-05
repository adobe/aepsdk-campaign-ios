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

import AEPServices
import Foundation

class CampaignHitProcessor: HitProcessing {
    private let LOG_TAG = "CampaignHitProcessor"

    private let timeout: TimeInterval
    private let dispatchQueue: DispatchQueue
    private let responseHandler: (CampaignHit) -> Void
    private let headers = [NetworkServiceConstants.Headers.CONTENT_TYPE: CampaignConstants.Campaign.CONTENT_TYPE_JSON, CampaignConstants.Campaign.HEADER_KEY_ACCEPT: "*/*"]

    /// Creates a new `CampaignHitProcessor` where the `responseHandler` will be invoked after the successful sending of a hit
    /// - Parameters:
    ///   - timeout: A `TimeInterval` containing the configured Campaign request timeout
    ///   - responseHandler: a function to be invoked with the successfully sent `CampaignHit`
    init(timeout: TimeInterval?, responseHandler: @escaping (CampaignHit) -> Void) {
        self.dispatchQueue = DispatchQueue(label: CampaignConstants.FRIENDLY_NAME)
        self.responseHandler = responseHandler
        self.timeout = timeout ?? TimeInterval(CampaignConstants.Campaign.DEFAULT_TIMEOUT)
    }

    // MARK: HitProcessing
    /// Returns the interval at which network requests should be retried.
    /// - Parameters:
    ///   - entity: A `DataEntity` containing a network request to be retried
    /// - Returns: a 30 second `TimeInterval`
    func retryInterval(for entity: DataEntity) -> TimeInterval {
        return TimeInterval(30)
    }

    /// Processes and attempts to send a network request contained in the provided `DataEntity`.
    /// - Parameters:
    ///   - entity: A `DataEntity` containing a network request to be sent
    ///   - completion: a completion block to invoke after we have processed the hit. The block is invoked with true if a hit was processed and false if it should be retried.
    func processHit(entity: DataEntity, completion: @escaping (Bool) -> Void) {
        guard let data = entity.data, let campaignHit = try? JSONDecoder().decode(CampaignHit.self, from: data) else {
            // Failed to convert data to hit, unrecoverable error, move to next hit
            completion(true)
            return
        }

        self.dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            let networkRequest = NetworkRequest(url: campaignHit.url,
                                                httpMethod: campaignHit.getHttpCommand(),
                                                connectPayload: campaignHit.payload,
                                                httpHeaders: self.headers,
                                                connectTimeout: self.timeout,
                                                readTimeout: self.timeout)

            ServiceProvider.shared.networkService.connectAsync(networkRequest: networkRequest) { [weak self] connection in
                self?.handleNetworkResponse(hit: campaignHit,
                                            connection: connection,
                                            completion: completion
                )
            }
        }
    }

    // MARK: Helpers

    /// Handles the network response after a hit has been sent to the server
    /// - Parameters:
    ///   - hit: the `CampaignHit`
    ///   - connection: the connection returned after we make the network request
    ///   - completion: a completion block to invoke after we have handled the network response with true for success and false for failure (retry)
    private func handleNetworkResponse(hit: CampaignHit, connection: HttpConnection, completion: @escaping (Bool) -> Void) {
        if connection.responseCode == 200 {
            // Hit sent successfully
            Log.debug(label: LOG_TAG, "\(#function) - Campaign hit with url \(hit.url.absoluteString) and payload \(hit.payload) sent successfully")
            responseHandler(hit)
            completion(true)
        } else if NetworkServiceConstants.RECOVERABLE_ERROR_CODES.contains(connection.responseCode ?? -1) {
            // retry this hit later
            Log.warning(label: LOG_TAG, "\(#function) - Retrying Campaign hit, request with url \(hit.url.absoluteString) failed with error \(connection.error?.localizedDescription ?? "") and recoverable status code \(connection.responseCode ?? -1)")
            completion(false)
        } else if let error = connection.error {
            // retry this hit later if the error code is `notConnectedToInternet`. other
            if let urlError = error as? URLError, urlError.code == URLError.Code.notConnectedToInternet {
                Log.warning(label: LOG_TAG, "\(#function) - Retrying Campaign hit, there is currently no network connectivity")
                completion(false)
            } else {
                Log.warning(label: LOG_TAG, "\(#function) - Dropping Campaign hit, request with url \(hit.url.absoluteString) failed with error \(error.localizedDescription)")
                completion(true)
            }
        } else {
            // unrecoverable error. delete the hit from the database and continue
            Log.warning(label: LOG_TAG, """
                \(#function) - Dropping Campaign hit, request with url \(hit.url.absoluteString) failed with error \(connection.error?.localizedDescription ?? "") and unrecoverable status code \(connection.responseCode ?? -1)
            """)
            completion(true)
        }
    }
}
