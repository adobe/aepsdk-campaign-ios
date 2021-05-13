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

extension CampaignFullscreenMessage: FullscreenMessageDelegate {
    /// Invoked when a Campaign Fullscreen Message is displayed.
    /// Triggers a call to parent method `triggered()`
    ///  - Parameter message: the Campaign Fullscreen Message being displayed
    func onShow(message: FullscreenMessage) {
        Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Fullscreen on show callback received.")
        triggered()
    }

    /// Invoked when a Campaign Fullscreen Message is dismissed.
    /// Triggers a call to parent method `viewed()`
    ///  - Parameter message: the Campaign Fullscreen Message being dismissed
    func onDismiss(message: FullscreenMessage) {
        Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Fullscreen on dismiss callback received.")
        viewed()
    }

    /// Invoked when a Campaign Fullscreen Message is attempting to load a URL.
    /// The provided url can be in one of the following forms:
    ///  * adbinapp://confirm?id={broadlogId},{deliveryId},3&url={clickThroughUrl}}</li>
    ///  * adbinapp://confirm?id={broadlogId},{deliveryId},4}</li>
    ///  * adbinapp://cancel?id={broadlogId},{deliveryId},5}</li>
    /// Returns false if the scheme of the given url is not equal to "adbinapp" or if the host is not one of "confirm" or "cancel".
    /// The host and query information from the provided url is extracted in a [String: String] dictionary and
    /// passed to the default Message implementation to dispatch message click-through or viewed event.
    ///  - Parameters:
    ///    - message: the Campaign Fullscreen Message object
    ///    - url: A `String` containing the URL being loaded by the Message
    ///  - Returns: true if the SDK wants to handle the URL, false otherwise
    func overrideUrlLoad(message: FullscreenMessage, url: String?) -> Bool {
        guard let urlString = url, !urlString.isEmpty else {
            Log.error(label: CampaignConstants.LOG_TAG, "\(#function) - Cannot process provided URL string, it is nil or empty.")
            return false
        }
        Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Fullscreen overrideUrlLoad callback received with url \(urlString)")

        // convert url to url components
        guard let url = URL(string: urlString), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Log.error(label: CampaignConstants.LOG_TAG, "\(#function) - Unable to create a url from \(urlString).")
            return false
        }

        // check adbinapp scheme. if it's a cache file url the AEPSDK will handle it. otherwise check for an adobe deeplink scheme.
        let scheme = components.scheme
        if scheme == CampaignConstants.Campaign.Scheme.FILE {
            return true
        } else if scheme != CampaignConstants.Campaign.MessagePayload.DEEPLINK_SCHEME {
            Log.error(label: CampaignConstants.LOG_TAG, "\(#function) - Invalid message scheme found in URI: \(url.scheme ?? "").")
            return false
        }

        // cancel or confirm
        guard let host = components.host, (host == CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_CONFIRM || host == CampaignConstants.EventDataKeys.RulesEngine.CONSEQUENCE_DETAIL_KEY_CANCEL) else {
            Log.error(label: CampaignConstants.LOG_TAG, "\(#function) - Unsupported URI host found, neither confirm nor cancel found in URI: \(urlString).")
            return false
        }

        // extract query parameters, eg: id=h11901a,86f10d,3&url=https://www.adobe.com
        guard let queryParameters = components.queryItems, !queryParameters.isEmpty else {
            Log.error(label: CampaignConstants.LOG_TAG, "\(#function) - No query parameters found in URI: \(urlString).")
            return false
        }

        // populate message data
        var messageData: [String: String] = [:]
        for queryParam in queryParameters {
            messageData[queryParam.name] = queryParam.value
        }

        if !messageData.isEmpty {
            messageData[CampaignConstants.Campaign.MessagePayload.INTERACTION_TYPE] = host
            processMessageInteraction(query: messageData)
        }
        message.dismiss()
        return true
    }

    func onShowFailure() {
        Log.debug(label: CampaignConstants.LOG_TAG, "\(#function) - Fullscreen message failed to show.")
    }
}
