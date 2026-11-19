#!/bin/bash

set -e # Any subsequent(*) commands which fail will cause the shell script to exit immediately

PROJECT_NAME=Swift6Consumer

# Clean up.
rm -rf $PROJECT_NAME

mkdir -p $PROJECT_NAME/Sources/$PROJECT_NAME && cd $PROJECT_NAME

# Create the Package.swift. Tools version 6.0 is required for swiftLanguageMode, and only the consumer target uses Swift 6.
echo "// swift-tools-version:6.0
import PackageDescription
let package = Package(
    name: \"$PROJECT_NAME\",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: \"$PROJECT_NAME\", targets: [\"$PROJECT_NAME\"])
    ],
    dependencies: [
        .package(name: \"AEPCampaign\", path: \"../\")
    ],
    targets: [
        .target(
            name: \"$PROJECT_NAME\",
            dependencies: [
                .product(name: \"AEPCampaign\", package: \"AEPCampaign\")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
" >Package.swift

# Main actor and SwiftUI consumers call every public Campaign API, the way a Swift 6 app would.
echo "import AEPCampaign
import AEPCore
import AEPIdentity
import SwiftUI

@MainActor
final class Swift6Consumer {
    var registered = false

    func exercise() {
        MobileCore.registerExtensions([Identity.self, Campaign.self])
        Campaign.setLinkageFields([\"cusFirstName\": \"John\"])
        Campaign.setLinkageFields([:])
        Campaign.resetLinkageFields()
        let version = Campaign.extensionVersion
        Task { @MainActor in self.registered = !version.isEmpty }
    }
}

struct Swift6ConsumerView: View {
    var body: some View {
        Button(\"Set linkage fields\") {
            Campaign.setLinkageFields([\"cusEmail\": \"john@example.com\"])
            Campaign.resetLinkageFields()
        }
    }
}
" >Sources/$PROJECT_NAME/$PROJECT_NAME.swift

swift package resolve

echo '############# Build Swift 6 consumer for generic iOS device ###############'
xcodebuild build -scheme $PROJECT_NAME -destination 'generic/platform=iOS'

echo '############# Build Swift 6 consumer for generic iOS Simulator ###############'
xcodebuild build -scheme $PROJECT_NAME -destination 'generic/platform=iOS Simulator'

# Clean up.
cd ../
rm -rf $PROJECT_NAME
