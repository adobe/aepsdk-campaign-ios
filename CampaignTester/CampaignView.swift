/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import UIKit
import SwiftUI
import AEPCampaign
import AEPCore

struct CampaignView: View {
    let LOG_TAG = "CampaignTester::CampaignView"

    // state vars
    @State private var extensionVersion: String = ""
    @State private var trackActionVar: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: HorizontalAlignment.leading, spacing: 12) {
                VStack {
                    Group {
                        /// Core Privacy API
                        Text("Core Privacy API").bold()

                        Button(action: {
                            MobileCore.setPrivacyStatus(PrivacyStatus.optedOut)
                        }) {
                            Text("OptOut")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)

                        Button(action: {
                            MobileCore.setPrivacyStatus(PrivacyStatus.optedIn)
                        }) {
                            Text("OptIn")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)

                        Button(action: {
                            MobileCore.setPrivacyStatus(PrivacyStatus.unknown)
                        }) {
                            Text("Unknown")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                    }
                    Group {
                        /// Campaign Testing buttons
                        Text("Notification Testing").bold()

                        Button(action: {
                            extensionVersion = Campaign.extensionVersion
                        }
                        ) {
                            Text("Extension Version")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                        TextField("Retrieved Extension Version", text: $extensionVersion)
                            .autocapitalization(.none)

                        Button(action: {
                            // trigger alert
                        }
                        ) {
                            Text("Trigger alert message")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)

                        Button(action: {
                            let localDetailDictionary = ["title": "ACS Local Notification Test", "detail": "This is some demo text 🌊☄️", "wait": TimeInterval(3), "userData": ["broadlogId": "h1cbf60",
                                                                                                                                                                              "deliveryId": "154767c"], "template": "local"] as [String: Any]
                            let localConsequence = ["id": UUID().uuidString, "type": "iam", "assetsPath": nil, "detailDictionary": localDetailDictionary] as [String: Any?]
                            let data = ["triggeredconsequence": localConsequence]
                            let event = Event(name: "rules trigger local notification", type: EventType.campaign, source: EventSource.requestContent, data: data)
                            MobileCore.dispatch(event: event)
                        }
                        ) {
                            Text("Trigger local notification")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                    }
                    Group {
                        /// Analytics Queue API
                        Button(action: {
                            // trigger fullscreen
                        }
                        ) {
                            Text("Trigger fullscreen message")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)

                        Button(action: {
                            // set linkage fields
                        }
                        ) {
                            Text("Set Linkage Fields")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)

                        Button(action: {
                            // reset linkage fields
                        }
                        ) {
                            Text("Reset Linkage Fields")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .font(.caption)
                        }.cornerRadius(5)
                    }
                }
            }
        }
    }
}

struct CampaignView_Previews: PreviewProvider {
    static var previews: some View {
        CampaignView()
    }
}
