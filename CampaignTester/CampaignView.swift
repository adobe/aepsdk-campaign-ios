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

import SwiftUI
import AEPCampaign
import AEPCore
import AEPServices

struct CampaignView: View {
    let LOG_TAG = "CampaignTester::CampaignView"

    // state vars
    @State private var extensionVersion: String = ""
    @State private var trackActionVar: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: nil, content: {
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
                        self.extensionVersion = Campaign.extensionVersion
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
                        MobileCore.track(action: "alert", data: nil)
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
                        MobileCore.track(action: "local", data: nil)
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
                    Button(action: {
                        MobileCore.track(action: "fullscreen", data: nil)
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
            )}
    }
}

struct CampaignView_Previews: PreviewProvider {
    static var previews: some View {
        CampaignView()
    }
}
