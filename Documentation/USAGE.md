# AEPCampaign Public APIs

This document contains usage information for the public functions and classes in `AEPCampaign`.

## Static functions

- [extensionVersion](#extensionVersion)
- [registerExtension](#registerExtension)
- [resetLinkageFields](#resetLinkageFields)
- [setLinkageFields](#setLinkageFields)

---

### extensionVersion

Returns the running version of the AEPCampaign extension.

##### Swift

**Signature**
```swift
static var extensionVersion: String
```

**Example Usage**
```swift
let campaignVersion = Campaign.extensionVersion
```

##### Objective-C

**Signature**
```objc
+ (nonnull NSString*) extensionVersion;
```

**Example Usage**
```objc
NSString *campaignVersion = [AEPMobileCampaign extensionVersion];
```
---

### registerExtension

This API no longer exists in `AEPCampaign`. Instead, the extension should be registered by calling the `registerExtensions` API in the `MobileCore`.

##### Swift

**Example:**
```swift
MobileCore.registerExtensions([Campaign.self, ...], {
  // processing after registration
})
```

##### Objective-C

**Example:**
```objc
[AEPMobileCore registerExtensions:@[AEPMobileCampaign.class, ...] completion:^{
  // processing after registration
}];
```

---

### resetLinkageFields

Clears previously stored linkage fields in the mobile SDK and triggers a Campaign rules download request to the configured Campaign server.

This method unregisters any previously registered rules with the Rules Engine and clears cached rules from the most recent rules download.

##### Swift

**Signature**
```swift
static func resetLinkageFields()
```

**Example Usage**
```swift
Campaign.resetLinkageFields()
```

##### Objective-C

**Signature**
```objc
+ (void) resetLinkageFields;
```

**Example Usage**
```objc
[AEPMobileCampaign resetLinkageFields];
```

---

### setLinkageFields

Sets the Campaign linkage fields (CRM IDs) in the mobile SDK to be used for downloading personalized messages from Campaign.

The set linkage fields are stored as a base64 encoded JSON string in memory and they are sent in a custom HTTP header 'X-InApp-Auth'

##### Swift

**Signature**
```swift
static func setLinkageFields(linkageFields: [String: String])
```

**Example Usage**
```swift
Campaign.setLinkageFields(linkageFields: ["cusFirstName": "John", "cusLastName": "Doe", "cusEmail": "john.doe@email.com"])
```

##### Objective-C

**Signature**
```objc
+ (void) setLinkageFields: (nonnull NSDictionary<NSString*, NSString*>*) linkageFields;
```

**Example Usage**
```objc
[AEPMobileCampaign setLinkageFields:@{@"cusFirstName" : @"John", @"cusLastName": @"Doe", @"cusEmail": @"john.doe@email.com"}];
```

---