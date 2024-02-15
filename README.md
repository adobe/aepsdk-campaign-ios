# Adobe Experience Platform Campaign SDK

[![Cocoapods](https://img.shields.io/github/v/release/adobe/aepsdk-campaign-ios?color=orange&label=CocoaPods&logo=apple&logoColor=white&sort=semver)](https://cocoapods.org/pods/AEPCampaign)
[![SPM](https://img.shields.io/github/v/release/adobe/aepsdk-campaign-ios?color=orange&label=SPM&logo=apple&logoColor=white&sort=semver)](https://github.com/adobe/aepsdk-campaign-ios/releases)
[![CircleCI](https://img.shields.io/circleci/project/github/adobe/aepsdk-campaign-ios/main.svg?logo=circleci&label=Build)](https://circleci.com/gh/adobe/workflows/aepsdk-campaign-ios)
[![Code Coverage](https://img.shields.io/codecov/c/github/adobe/aepsdk-campaign-ios/main.svg?logo=codecov&label=Coverage)](https://codecov.io/gh/adobe/aepsdk-campaign-ios/branch/main)

## About this project

The AEPCampaign extension represents the Campaign Standard Adobe Experience Platform SDK that is required for registering mobile devices with your Campaign instance as well as creating in-app messages for your mobile app. The extension also enables the setting of linkage fields for use in creating personalized in-app messages.

## Requirements
- Xcode 15 (or newer)
- Swift 5.1

## Installation
These are currently the supported installation options:

### [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html)
```ruby
# Podfile
use_frameworks!

# For app development, include all the following pods
target 'YOUR_TARGET_NAME' do
    pod 'AEPCampaign'
    pod 'AEPCore'
    pod 'AEPServices'
    pod 'AEPIdentity'
    pod 'AEPRulesEngine'
    pod `AEPUserProfile`
    pod `AEPLifecycle`
    pod `AEPSignal`
end

# For extension development, include AEPCampaign and its dependencies
target 'YOUR_TARGET_NAME' do
    pod 'AEPCampaign'
    pod 'AEPCore'
    pod 'AEPServices'
    pod 'AEPIdentity'
    pod 'AEPRulesEngine'
end
```

Replace `YOUR_TARGET_NAME` and then, in the `Podfile` directory, type:

```bash
$ pod install
```

### [Swift Package Manager](https://github.com/apple/swift-package-manager)

To add the AEPCampaign Package to your application, from the Xcode menu select:

`File > Swift Packages > Add Package Dependency...`

Enter the URL for the AEPCampaign package repository: `https://github.com/adobe/aepsdk-campaign-ios.git`.

When prompted, make sure you change the version to `5.0.0`.

Alternatively, if your project has a `Package.swift` file, you can add AEPCampaign directly to your dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/adobe/aepsdk-campaign-ios.git", .upToNextMajor(from: "5.0.0")),
],
targets: [
    .target(name: "YourTarget",
            dependencies: ["AEPCampaign"],
            path: "your/path")
]
```

### Project Reference

Include `AEPCampaign.xcodeproj` in the targeted Xcode project and link all necessary libraries to your app target.

### Binaries

Run `make archive` from the root directory to generate `.xcframeworks` for each module under the `build` folder. Drag and drop all `.xcframeworks` to your app target in Xcode.

## Documentation

Additional documentation for usage and SDK architecture can be found under the [Documentation](Documentation/README.md) directory.

## Contributing

Contributions are welcomed! Read the [Contributing Guide](./.github/CONTRIBUTING.md) for more information.

## Licensing

This project is licensed under the Apache V2 License. See [LICENSE](LICENSE) for more information.
