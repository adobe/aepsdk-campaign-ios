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
import AEPCore
import AEPServices

struct AlertMessage: CampaignMessaging {
    private static let LOG_TAG = "AlertMessage"

    var eventDispatcher: Campaign.EventDispatcher?
    var messageId: String?

    private var state: CampaignState?
    private var title: String?
    private var content: String?
    private var cancel: String?
    private var confirm: String?
    private var url: String?

    /// AlertMessage struct initializer. It is accessed via the `createMessageObject` method.
    ///  - Parameters:
    ///    - consequence: `RuleConsequence` containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    private init(consequence: RuleConsequence, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) {
        self.messageId = consequence.id
        self.eventDispatcher = eventDispatcher
        self.state = state
        self.parseAlertMessagePayload(consequence: consequence)
    }

    /// Creates an `AlertMessage` object
    ///  - Parameters:
    ///    - consequence: `RuleConsequence` containing a Message-defining payload
    ///    - state: The CampaignState
    ///    - eventDispatcher: The Campaign event dispatcher
    ///  - Returns: A Message object or nil if the message object creation failed.
    static func createMessageObject(consequence: RuleConsequence?, state: CampaignState, eventDispatcher: @escaping Campaign.EventDispatcher) -> CampaignMessaging? {
        guard let consequence = consequence else {
            Log.trace(label: LOG_TAG, "\(#function) - Cannot create an Alert Message object, the consequence is nil.")
            return nil
        }
        let alertMessage = AlertMessage(consequence: consequence, state: state, eventDispatcher: eventDispatcher)
        // title, content, and cancel text are required so no message object is returned if any of these are nil
        guard alertMessage.title != nil || alertMessage.content != nil || alertMessage.cancel != nil else {
            return nil
        }
        return alertMessage
    }

    /// Validates the alert message and if valid, displays the alert message using the `UIAlertController`.
    func showMessage() {
        guard let title = self.title, !title.isEmpty else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot show alert message, the message title is nil.")
            return
        }
        guard let content = self.content, !content.isEmpty else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot show alert message, the message content is nil.")
            return
        }
        guard let cancelText = self.cancel, !cancelText.isEmpty else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Cannot show alert message, the cancel button text is nil.")
            return
        }

        let uiAlert = UIAlertController(title: title, message: content, preferredStyle: .alert)
        uiAlert.addAction(UIAlertAction(title: cancelText, style: .cancel, handler: { _ in
            viewed()
        }))

        if let confirmText = self.confirm, !confirmText.isEmpty {
            uiAlert.addAction(UIAlertAction(title: confirmText, style: .default, handler: { _ in
                clickedThrough()
                if let url = self.url, !url.isEmpty {
                    openUrl(url: URL(string: url))
                }
            }))
        }

        let messageId = self.messageId ?? ""
        Log.trace(label: Self.LOG_TAG, "\(#function) - Showing alert for message id \(messageId).")
        DispatchQueue.main.async {
            if let viewController = UIApplication.getCurrentViewController() {
                viewController.present(uiAlert, animated: true) {
                    triggered()
                }
            }
        }
    }

    /// Parses a `CampaignRuleConsequence` instance defining message payload for a `AlertMessage` object.
    /// Required fields:
    ///     * title: A `String` containing the title for this message
    ///     * content: A `String` containing the message content for this message
    ///     * cancel: A `String` containing the text of the cancel or negative action button on this message
    /// Optional fields:
    ///     * confirm: A `String` containing the text of the confirm or positive action button on this message
    ///     * url: A `String` containing a URL destination to be shown on positive click-through
    ///  - Parameter consequence: `RuleConsequence` containing a Message-defining payload
    private mutating func parseAlertMessagePayload(consequence: RuleConsequence) {
        guard !consequence.details.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The consequence details are nil or empty, dropping the alert message.")
            return
        }
        // title is required
        guard let title = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.TITLE] as? String, !title.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The title for an alert message is required, dropping the notification.")
            return
        }
        self.title = title

        // content is required
        guard let content = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.CONTENT] as? String, !content.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The content for an alert message is required, dropping the notification.")
            return
        }
        self.content = content

        // cancel button text is required
        guard let cancelText = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.CANCEL] as? String, !cancelText.isEmpty else {
            Log.error(label: Self.LOG_TAG, "\(#function) - The cancel button text for an alert message is required, dropping the notification.")
            return
        }
        self.cancel = cancelText

        // confirm button text is optional
        if let confirmText = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.CONFIRM] as? String, !confirmText.isEmpty {
            self.confirm = confirmText
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read confirm button text for an alert message but found none. This is not a required field.")
        }

        // url is optional
        if let url = consequence.details[CampaignConstants.EventDataKeys.RulesEngine.Detail.URL] as? String, !url.isEmpty {
            self.url = url
        } else {
            Log.trace(label: Self.LOG_TAG, "\(#function) - Tried to read url for an alert message but found none. This is not a required field.")
        }
    }

    // no-op for alert messages
    internal func shouldDownloadAssets() -> Bool {
        return false
    }
}

/// UIApplication extension to get the currently visible ViewController on which the Alert message should be displayed.
extension UIApplication {
    class func getCurrentViewController(_ viewController: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = viewController as? UINavigationController {
            return getCurrentViewController(nav.visibleViewController)
        }
        if let tab = viewController as? UITabBarController {
            if let selected = tab.selectedViewController {
                return getCurrentViewController(selected)
            }
        }
        if let presented = viewController?.presentedViewController {
            return getCurrentViewController(presented)
        }
        return viewController
    }
}
