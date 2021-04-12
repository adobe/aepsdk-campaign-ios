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

enum CampaignConstants {
    static let EXTENSION_NAME                           = "com.adobe.module.campaign"
    static let FRIENDLY_NAME                            = "Campaign"
    static let EXTENSION_VERSION                        = "0.0.1"
    static let DATASTORE_NAME                           = EXTENSION_NAME

    enum Campaign {
        static let MESSAGE_CACHE_FOLDER = "messages"
        static let IAM_CONSEQUENCE_TYPE = "iam"
        static let LINKAGE_FIELD_NETWORK_HEADER = "X-InApp-Auth"
        static let DEFAULT_TIMEOUT = TimeInterval(5)
        static let PUSH_PLATFORM = "pushPlatform"
        static let DEFAULT_REGISTRATION_DELAY = TimeInterval(60 * 60 * 24 * 7) // 7 days
        static let DEFAULT_TIMESTAMP_VALUE = -1
        static let SECONDS_IN_A_DAY = TimeInterval(86400) // check if still needed
        static let MILLISECONDS_IN_A_SECOND = 1000 // check if still needed
        static let SERVER_TOKEN =
            "{%~state.com.adobe.module.configuration/campaign.server%}"
        static let PROPERTY_TOKEN =
            "{%~state.com.adobe.module.configuration/property.id%}"
        static let IDENTITY_ECID_TOKEN = "{%~state.com.adobe.module.identity/mid%}"
        static let MESSAGE_ID_TOKEN = "messageId"

        static let PROFILE_URL = "https://%s/rest/head/mobileAppV5/%s/subscriptions/%s"
        static let RULES_DOWNLOAD_URL = "https://%s/%s/%s/%s/rules.zip"
        static let TRACKING_URL = "https://%s/r/?id=%s,%s,%s&mcId=%s"
        static let CAMPAIGN_ENV_PLACEHOLDER = "__%s__"

        enum Datastore {
            static let NAME = "CampaignDataStore"
            static let REMOTE_URL_KEY = "CampaignRemoteUrl"
            static let ECID_KEY = "ExperienceCloudId"
            static let REGISTRATION_TIMESTAMP_KEY = "CampaignRegistrationTimestamp"
        }

        enum MessagePayload {
            static let TEMPLATE_ALERT = "alert"
            static let TEMPLATE_FULLSCREEN = "fullscreen"
            static let TEMPLATE_LOCAL = "local"
            static let DEEPLINK_SCHEME = "adbinapp"
            static let INTERACTION_URL  = "url"
            static let INTERACTION_TYPE  = "type"
        }

        enum AppEnvironment {
            static let DEV = "dev"
            static let STAGE = "stage"
        }

        enum Rules {
            static let CACHE_FOLDER = "campaignRules"
            static let JSON_KEY = "rules"
            static let JSON_FILE_NAME = "rules.json"
            static let JSON_CONDITION_KEY = "condition"
            static let JSON_CONSEQUENCES_KEY = "consequences"
            static let ASSETS_DIRECTORY = "assets"
        }
    }

    enum Configuration {
        static let EXTENSION_NAME = "com.adobe.module.configuration"
        static let GLOBAL_CONFIG_PRIVACY = "global.privacy"
        static let PROPERTY_ID = "property.id"
        static let CAMPAIGN_SERVER  = "campaign.server"
        static let CAMPAIGN_PKEY = "campaign.pkey"
        static let CAMPAIGN_MCIAS = "campaign.mcias"
        static let CAMPAIGN_TIMEOUT = "campaign.timeout"
        static let CAMPAIGN_REGISTRATION_DELAY_KEY =
            "campaign.registrationDelay"
        static let CAMPAIGN_REGISTRATION_PAUSED_KEY =
            "campaign.registrationPaused"
    }
    enum Identity {
        static let EXTENSION_NAME = "com.adobe.module.identity"
        static let EXPERIENCE_CLOUD_ID = "marketingCloudId"
    }
    enum Lifecycle {
        static let EXTENSION_NAME = "com.adobe.module.lifecycle"
        static let LAUNCH_EVENT = "launchevent"
        static let CONTEXT_DATA = "lifecyclecontextdata"
    }

    // MARK: EventDataKeys
    enum EventDataKeys {
        static let MESSAGE_TRIGGERED_ACTION_VALUE = "7"
        static let MESSAGE_TRIGGERED = "a.message.triggered"
        static let MESSAGE_CLICKED = "a.message.clicked"
        static let MESSAGE_VIEWED = "a.message.viewed"
        static let MESSAGE_ID = "a.message.id"
        static let STATE_OWNER = "stateowner"
        static let LINKAGE_FIELDS = "linkagefields"
        static let TRACK_INFO_KEY_BROADLOG_ID  = "broadlogId"
        static let TRACK_INFO_KEY_DELIVERY_ID  = "deliveryId"
        static let TRACK_INFO_KEY_ACTION = "action"

        enum RulesEngine {
            static let CONSEQUENCE_ID = "id"
            static let CONSEQUENCE_TYPE = "type"
            static let CONSEQUENCE_DETAIL = "detail"
            static let CONSEQUENCE_DETAIL_KEY_TEMPLATE = "template"
            static let CONSEQUENCE_DETAIL_KEY_TITLE = "title"
            static let CONSEQUENCE_DETAIL_KEY_CONTENT = "content"
            static let CONSEQUENCE_DETAIL_KEY_URL = "url"
            static let CONSEQUENCE_DETAIL_KEY_CONFIRM = "confirm"
            static let CONSEQUENCE_DETAIL_KEY_CANCEL = "cancel"
            static let CONSEQUENCE_DETAIL_KEY_HTML = "html"
            static let CONSEQUENCE_DETAIL_KEY_REMOTE_ASSETS = "remoteAssets"
            static let CONSEQUENCE_DETAIL_KEY_WAIT = "wait"
            static let CONSEQUENCE_DETAIL_KEY_SOUND = "sound"
            static let CONSEQUENCE_DETAIL_KEY_CATEGORY = "category"
            static let CONSEQUENCE_DETAIL_KEY_DEEPLINK = "adb_deeplink"
            static let CONSEQUENCE_DETAIL_KEY_USER_INFO = "userData"
            static let CONSEQUENCE_DETAIL_KEY_DATE = "date"
            static let CONSEQUENCE_ASSETS_PATH = "assetsPath"
            static let TRIGGERED_CONSEQUENCES = "triggeredconsequence"
            static let LOADED_CONSEQUENCES = "loadedconsequences"
        }
    }
}
