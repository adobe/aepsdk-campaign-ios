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
                        let localDetailDictionary = ["title": "ACS Local Notification Test", "content": "This is some demo text 🌊☄️", "wait": TimeInterval(3), "userData": ["broadlogId": "h1cbf60",
                                                                                                                                                                           "deliveryId": "154767c"], "template": "local"] as [String: Any]
                        let localConsequence = ["id": UUID().uuidString, "type": "iam", "detail": localDetailDictionary] as [String: Any?]
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
                    Button(action: {
                        addTestHtmlToCache()
                        let fullscreenDetailDictionary = ["html": "test.html", "template": "fullscreen"] as [String: Any]
                        let fullscreenConsequence = ["id": UUID().uuidString, "type": "iam", "detail": fullscreenDetailDictionary] as [String: Any?]
                        let data = ["triggeredconsequence": fullscreenConsequence]
                        let event = Event(name: "rules trigger fullscreen message", type: EventType.campaign, source: EventSource.requestContent, data: data)
                        MobileCore.dispatch(event: event)
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

func addTestHtmlToCache() {
    let htmlString = "<html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1,minimum-scale=1\"><meta name=\"ADBMessageAssets\" content='[\r\n    [ \"https://i.imgur.com/FEt4fFm.gif\", \"\" ]\r\n  ]'><style>body,html{margin:0;padding:0;text-align:center;width:100%;height:100%;font-family:Arial,Helvetica,sans-serif;user-select:none;overflow:hidden;box-sizing:border-box;background-color:transparent;display:-webkit-box;display:-webkit-flex;display:-ms-flexbox;display:flex;align-items:stretch}a{text-decoration:none}.nl-dce-field{white-space:nowrap!important;color:#2886dc!important;text-shadow:none!important;border:3px solid #c3dbf0!important;cursor:pointer!important;background-color:#cae4fc!important;margin:0!important;padding:0!important}.close-button{display:none;position:absolute;top:10px;right:10px;box-sizing:border-box;cursor:pointer;border-radius:12px;font-size:40px;height:50px;width:50px;line-height:50px;margin:6px;z-index:5;color:#000}.visible-true{display:block}.media{display:none;max-height:50%}.text-and-buttons{flex:1;display:flex;flex-direction:column;justify-content:center}.text{flex:1 1 auto;display:flex;flex-direction:column;justify-content:center;align-items:center}.header{margin:.67em 10px}.message{margin:0 10px}.modal-container{position:relative;display:flex;flex-direction:column;flex:1 1 auto;overflow:hidden}.modal-container,.text-and-buttons{background-color:#e8eae9}@media only screen and (orientation:portrait){.html-modal.small .modal-container{margin:20% 8%}}@media only screen and (orientation:landscape){.html-modal.small .modal-container{margin:50px 20%}}.html-modal.large .modal-container{margin:5%}.theme-dark .close-button,.theme-dark .modal-container,.theme-dark .text-and-buttons{background-color:#282828;color:#fff}.theme-dark .message{color:#c4c4c4}.theme-dark .buttons{color:#fff}.includes-media-image .close-button{background-color:transparent}.buttons{height:150px;display:flex;align-items:center;justify-content:center}.button-margin{width:100%;margin:0 44px}.button{position:relative;display:block;width:100%;white-space:nowrap;text-overflow:ellipsis;min-width:20px;line-height:44px;height:44px;color:#fff;background-color:#999;text-align:center;cursor:pointer;overflow:hidden;outline:0;margin:0;border-style:solid;border-width:0 1px;border-color:#999;border-radius:6px}.button.confirm{background-color:#007ccf;border-color:#007ccf;margin-bottom:18px}.button:active,.button:hover{background-color:#666;border-color:#666}.button.confirm:active,.button.confirm:hover{background-color:#0268a0;border-color:#0268a0}.button:empty{display:none}video{display:none}.includes-media-image .media,.includes-media-video .media{flex:1;display:flex;align-items:center;justify-content:center;height:50%}.includes-media-image.media-only .media,.includes-media-video.media-only .media{max-height:100%;height:100%}.includes-media-image .media{background-size:cover;background-position:center}.includes-media-video .media{background:0 0!important}.includes-media-video video{display:block;max-width:100%}.button-align-horizontal .button-margin{margin:0 20px}.button-align-horizontal .buttons{height:100px}.button-align-horizontal .button{width:calc(50% - 12px);float:right;margin:0;height:60px;line-height:60px}.button-align-horizontal .button.confirm{float:left}.button-align-horizontal .button-margin.single{display:flex;justify-content:center}@media only screen and (max-width:812px) and (orientation:landscape){.has-media .modal-container{display:block}.has-media .text-and-buttons{height:100%}.includes-media-image.has-media .text-and-buttons,.includes-media-video.has-media .text-and-buttons{position:absolute;left:40%;top:0;right:0;bottom:0}.includes-media-image.has-media .media,.includes-media-video.has-media .media{position:absolute;right:40%;top:0;left:0;bottom:0;max-height:100%;height:100%}.includes-media-image.has-media.media-only .media,.includes-media-video.has-media.media-only .media{right:0}.includes-media-image.has-media .text-and-buttons{background:-webkit-linear-gradient(left,rgba(237,237,237,0),#ededed 30%,#ededed);background:-ms-linear-gradient(left,rgba(237,237,237,0),#ededed 30%,#ededed);background:linear-gradient(to right,rgba(237,237,237,0),#ededed 30%,#ededed)}.includes-media-image.has-media.theme-dark .text-and-buttons{background:-webkit-linear-gradient(left,rgba(40,40,40,0),#282828 30%,#282828);background:-ms-linear-gradient(left,rgba(40,40,40,0),#282828 30%,#282828);background:linear-gradient(to right,rgba(40,40,40,0),#282828 30%,#282828)}.includes-media-image.has-media .buttons,.includes-media-image.has-media .text{margin-left:30%}.includes-media-image.has-media .close-button{left:10px}.includes-media-video.has-media .text-and-buttons{left:50%}.includes-media-video.has-media .media{right:50%}.buttons{height:140px}.button-align-horizontal .buttons{height:100px}}</style></head><body class=\"html-full theme-dark button-align-horizontal includes-media-image\" data-auto-dismiss=\"\" data-auto-dismiss-duration=\"\"><div class=\"modal-container\"><a class=\"close-button visible-true\" href=\"adbinapp://cancel?id=h18a880,103b8f5,5\">&times;</a><div id=\"media\" class=\"media\" style=\"background-image:url(https://i.imgur.com/FEt4fFm.gif)\" data-media-type=\"image\" data-media-url=\"https://i.imgur.com/FEt4fFm.gif\" data-bundled-image-path=\"\"><video controls src=\"https://i.imgur.com/FEt4fFm.gif\" poster=\"\"></video></div><div class=\"text-and-buttons\"><div id=\"text\" class=\"text\"><h1 class=\"header\">fullscreen until click</h1><div class=\"message\">fullscreen until click</div></div><div id=\"buttons\" class=\"buttons\"><div class=\"button-margin\"><a id=\"button1\" class=\"button confirm\" data-destination-url=\"https://www.adobe.com\" data-text=\"yes\" href=\"adbinapp://confirm/?id=h18a880,103b8f5,3\">yes</a> <a id=\"button2\" class=\"button\" data-destination-url=\"\" data-text=\"no\" href=\"adbinapp://confirm/?id=h18a880,103b8f5,4\">no</a></div></div></div></div><script>!function(){var e=document.getElementById(\"media\"),t=\"image\"===e.dataset.mediaType,a=\"video\"===e.dataset.mediaType,n=\"\"!==e.dataset.mediaUrl.trim(),d=\"\"!==e.dataset.bundledImagePath.trim(),m=document.getElementById(\"button1\"),r=\"\"!==m.dataset.text.trim(),i=m.dataset.destinationUrl.trim(),o=\"\"!==i,l=document.getElementById(\"button2\"),s=\"\"!==l.dataset.text.trim(),u=l.dataset.destinationUrl.trim(),c=\"\"!==u,v=\"\"!==document.querySelector(\"h1.header\").innerText.trim(),y=\"\"!==document.querySelector(\"div.message\").innerText.trim(),h=\"true\"===document.body.dataset.autoDismiss,p=document.body.dataset.autoDismissDuration;if(t&&!1===n&&!1===d||a&&!1===n)e.parentElement.removeChild(e);else if(document.body.className+=\" has-media\",t){var E=document.querySelector(\"video\");E.parentElement.removeChild(E)}if(h){var b=parseInt(p);setTimeout(function(){window.location.href=\"adbinapp://cancel?id=h18a880,103b8f5,5\"},1e3*b)}var f=function(e,t){e.setAttribute(\"href\",e.getAttribute(\"href\")+t)};if(r?o&&f(m,\"&url=\"+i):m.parentElement.removeChild(m),s?c&&f(l,\"&url=\"+u):l.parentElement.removeChild(l),r&&!s&&(m.parentElement.className+=\" single\"),!r&&s&&(l.parentElement.className+=\" single\"),r||s||v||y){if(!v&&!y){var g=document.getElementById(\"text\");g.parentElement.removeChild(g)}if(!r&&!s){var I=document.getElementById(\"buttons\");I.parentElement.removeChild(I)}}else{var C=document.querySelector(\"div.text-and-buttons\");C.parentElement.removeChild(C),document.body.className+=\" media-only\"}}()</script></body></html>"
    let rulesCache = Cache(name: "rules.cache")
    if let data = htmlString.data(using: .utf8) {
        let cacheEntry = CacheEntry(data: data, expiry: .never, metadata: nil)
        try? rulesCache.set(key: "campaignrules/assets/test.html", entry: cacheEntry)
    }
}

struct CampaignView_Previews: PreviewProvider {
    static var previews: some View {
        CampaignView()
    }
}
