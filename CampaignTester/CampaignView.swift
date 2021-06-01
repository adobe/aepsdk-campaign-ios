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
import AEPAssurance

class LinkageFieldsError: ObservableObject {
    @Published var errorObserved: Bool = false

    public func didSeeLinkageFieldsError() {
        self.errorObserved = true
    }

    public func reset() {
        self.errorObserved = false
    }
}

@available(iOS 14.0, *)
struct CampaignView: View {
    let LOG_TAG = "CampaignTester::CampaignView"

    @StateObject var errorObserver: LinkageFieldsError = LinkageFieldsError()

    // state vars
    @State private var extensionVersion: String = ""
    @State private var trackActionVar: String = ""
    @State private var firstname: String = UserDefaults.standard.string(forKey: "FirstName") ?? ""
    @State private var lastname: String = UserDefaults.standard.string(forKey: "LastName") ?? ""
    @State private var email: String = UserDefaults.standard.string(forKey: "Email") ?? ""
    @State private var assuranceURL: String = ""

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
                        MobileCore.track(action: "fullscreenmp4", data: nil)
                    }
                    ) {
                        Text("Trigger fullscreen message with video")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .font(.caption)
                    }.cornerRadius(5)
                    Button(action: {
                        MobileCore.track(action: "personalized", data: nil)
                    }
                    ) {
                        Text("Trigger personalized fullscreen IAM.")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .font(.caption)
                    }.cornerRadius(5)
                    Text("Note: Personalized IAM must be created on ACS after setting linkage fields to target that user.")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .font(.callout)
                    TextField("First Name:", text: $firstname).autocapitalization(.none)
                    TextField("Last Name:", text: $lastname).autocapitalization(.none)
                    TextField("Email:", text: $email).autocapitalization(.none)
                    Button(action: {
                        // save the entered linkage fields to user defaults
                        updateUserDefaults(clearDefaults: false)
                        guard !firstname.isEmpty, !lastname.isEmpty, !email.isEmpty else {
                            errorObserver.didSeeLinkageFieldsError()
                            return
                        }
                        // invoke the linkage fields API and invoke collectPii to update the acs subscriber table
                        setLinkageFieldsAndUpdateAcsSubscriber()
                    }
                    ) {
                        Text("Set Linkage Fields")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .font(.caption)
                    }.cornerRadius(5)
                }
                Group {
                    Button(action: {
                        Campaign.resetLinkageFields()
                        // reset user defaults
                        updateUserDefaults(clearDefaults: true)
                        // reset observer
                        errorObserver.reset()
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
                Group {
                    Text("Configure Assurance").bold().frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                    TextField("Enter Assurance URL", text: $assuranceURL)
                    Button(action: {
                        guard let url = URL(string: self.assuranceURL) else {
                            Log.debug(label: LOG_TAG, "Unable to start Assurance session. Invalid URL.")
                            return
                        }
                        AEPAssurance.startSession(url)
                    }) {
                        Text("Start Assurance Session")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .font(.caption)
                    }.cornerRadius(5)
                }
            }
            )}.alert(isPresented: $errorObserver.errorObserved, content: {
            Alert(title: Text("Set Linkage Fields Error"),
                  message: Text("First name, last name, and email are required."),
                  dismissButton: .default(Text("OK")) {})
        })
    }
    func updateUserDefaults(clearDefaults: Bool) {
        if !clearDefaults {
            UserDefaults.standard.setValue(firstname, forKey: "FirstName")
            UserDefaults.standard.setValue(lastname, forKey: "LastName")
            UserDefaults.standard.setValue(email, forKey: "Email")
        } else {
            UserDefaults.standard.removeObject(forKey: "FirstName")
            UserDefaults.standard.removeObject(forKey: "LastName")
            UserDefaults.standard.removeObject(forKey: "Email")
            firstname = ""
            lastname = ""
            email = ""
        }
    }

    func setLinkageFieldsAndUpdateAcsSubscriber() {
        // build user login data dictionary
        var loginData = ["cusFirstName": firstname, "cusLastName": lastname, "cusEmail": email]
        Campaign.setLinkageFields(linkageFields: loginData)
        loginData["triggerKey"] = "collectPIIIOS"
        // update ACS subscriber table with login data
        MobileCore.collectPii(loginData)
    }
}

struct CampaignView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 14.0, *) {
            CampaignView()
        } else {
            // Fallback on earlier versions
        }
    }
}

#if canImport(UIKit)
    extension View {
        func hideKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
#endif
