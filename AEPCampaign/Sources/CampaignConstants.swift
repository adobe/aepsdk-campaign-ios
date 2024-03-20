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
    static let EXTENSION_VERSION                        = "5.0.0"
    static let DATASTORE_NAME                           = EXTENSION_NAME
    static let LOG_TAG                                  = FRIENDLY_NAME

    enum Campaign {
        static let IAM_CONSEQUENCE_TYPE = "iam"
        static let LINKAGE_FIELD_NETWORK_HEADER = "X-InApp-Auth"
        static let DEFAULT_TIMEOUT = 5
        static let PROFILE_REQUEST_PUSH_PLATFORM = "pushPlatform"
        static let PROFILE_REQUEST_EXPERIENCE_CLOUD_ID = "marketingCloudId"
        static let DEFAULT_REGISTRATION_DELAY = TimeInterval(60 * 60 * 24 * 7) // 7 days
        static let DEFAULT_TIMESTAMP_VALUE = TimeInterval(-1)
        static let SECONDS_IN_A_DAY = 86_400
        static let SERVER_TOKEN =
            "{%~state.com.adobe.module.configuration/campaign.server%}"
        static let PROPERTY_TOKEN =
            "{%~state.com.adobe.module.configuration/property.id%}"
        static let IDENTITY_ECID_TOKEN = "{%~state.com.adobe.module.identity/mid%}"
        static let MESSAGE_ID_TOKEN = "messageId"
        static let PROFILE_URL_PATH = "/rest/head/mobileAppV5/%@/subscriptions/%@"
        static let RULES_DOWNLOAD_PATH = "/mcias/%@/%@/%@/rules.zip"
        static let TRACKING_URL = "https://%@/r/?id=%@,%@,%s&mcId=%@"
        static let CAMPAIGN_ENV_PLACEHOLDER = "__%@__"
        static let PATH_SEPARATOR = "/"
        static let CONTENT_TYPE_JSON = "application/json"
        static let HEADER_KEY_ACCEPT = "Accept"

        enum Scheme {
            static let FILE = "file"
            static let HTTPS = "https"
        }

        enum Datastore {
            static let NAME = "CampaignDataStore"
            static let REMOTE_URL_KEY = "CampaignRemoteUrl"
            static let ECID_KEY = "ExperienceCloudId"
            static let REGISTRATION_TIMESTAMP_KEY = "CampaignRegistrationTimestamp"
        }

        enum MessagePayload {
            static let DEEPLINK_SCHEME = "adbinapp"
            static let INTERACTION_URL = "url"
            static let INTERACTION_TYPE = "type"
        }

        enum MessageData {
            static let ID_TOKENS_LEN = 3
            static let TAG_ID = "id"
            static let TAG_ID_DELIMITER = ","
            static let TAG_ID_BUTTON_1 = "3"
            static let TAG_ID_BUTTON_2 = "4"
            static let TAG_ID_BUTTON_X = "5"
        }

        enum AppEnvironment {
            static let DEV = "dev"
            static let STAGE = "stage"
        }

        enum Rules {
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
        static let GLOBAL_CONFIG_BUILD_ENVIRONMENT = "build.environment"
        static let PROPERTY_ID = "property.id"
        static let CAMPAIGN_SERVER = "campaign.server"
        static let DEV_CAMPAIGN_SERVER = "__dev__campaign.server"
        static let STAGE_CAMPAIGN_SERVER = "__stage__campaign.server"
        static let CAMPAIGN_PKEY = "campaign.pkey"
        static let DEV_PKEY = "__dev__campaign.pkey"
        static let STAGE_PKEY = "__stage__campaign.pkey"
        static let CAMPAIGN_MCIAS = "campaign.mcias"
        static let CAMPAIGN_TIMEOUT = "campaign.timeout"
        static let CAMPAIGN_REGISTRATION_DELAY_KEY =
            "campaign.registrationDelay"
        static let CAMPAIGN_REGISTRATION_PAUSED_KEY =
            "campaign.registrationPaused"
    }

    enum Identity {
        static let EXTENSION_NAME = "com.adobe.module.identity"
        static let EXPERIENCE_CLOUD_ID = "mid"
    }

    enum Lifecycle {
        static let EXTENSION_NAME = "com.adobe.module.lifecycle"
        static let LAUNCH_EVENT = "launchevent"
        static let CONTEXT_DATA = "lifecyclecontextdata"
    }

    enum ContextDataKeys {
        static let MESSAGE_TRIGGERED = "a.message.triggered"
        static let MESSAGE_CLICKED = "a.message.clicked"
        static let MESSAGE_VIEWED = "a.message.viewed"
        static let MESSAGE_ID = "a.message.id"
        static let MESSAGE_ACTION_EXISTS_VALUE = "1"
    }

    // MARK: EventDataKeys
    enum EventDataKeys {
        static let MESSAGE_TRIGGERED_ACTION_VALUE = "7"
        static let MESSAGE_CLICKED_ACTION_VALUE = "2"
        static let MESSAGE_VIEWED_ACTION_VALUE = "1"
        static let STATE_OWNER = "stateowner"
        static let LINKAGE_FIELDS = "linkagefields"
        static let TRACK_INFO_KEY_BROADLOG_ID  = "broadlogId"
        static let TRACK_INFO_KEY_DELIVERY_ID  = "deliveryId"
        static let TRACK_INFO_KEY_ACTION = "action"

        enum RulesEngine {
            static let ID = "id"
            static let TYPE = "type"
            static let ASSETS_PATH = "assetsPath"
            static let TRIGGERED_CONSEQUENCES = "triggeredconsequence"
            static let LOADED_CONSEQUENCES = "loadedconsequences"
            static let DETAIL = "detail"
            enum Detail {
                static let TEMPLATE = "template"
                static let TITLE = "title"
                static let CONTENT = "content"
                static let URL = "url"
                static let CONFIRM = "confirm"
                static let CANCEL = "cancel"
                static let HTML = "html"
                static let REMOTE_ASSETS = "remoteAssets"
                static let WAIT = "wait"
                static let SOUND = "sound"
                static let CATEGORY = "category"
                static let DEEPLINK = "adb_deeplink"
                static let USER_INFO = "userData"
                static let DATE = "date"
            }
        }
    }

    enum RulesDownloaderConstants {
        static let RULES_CACHE_NAME = "campaign.rules.cache"
        static let RULES_ZIP_FILE_NAME = "rules.zip"
        static let RULES_TEMP_DIR = "com.adobe.rules.campaign" // A temp folder where Campaign rules.zip is downloaded
        static let CAMPAIGN_CACHE = "campaign"
        static let RULES_CACHE_FOLDER = "\(CAMPAIGN_CACHE)/campaignrules"
        static let MESSAGE_CACHE_FOLDER = "\(CAMPAIGN_CACHE)/messages"
        static let ASSETS_DIR_NAME = "assets"
        enum Keys {
            static let RULES_CACHE_PREFIX = "cached.campaignrules."
        }
    }
}
