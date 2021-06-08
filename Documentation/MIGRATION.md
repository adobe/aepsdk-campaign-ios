# Migration from ACPCampaign to AEPCampaign

This document is a reference comparison of ACPCampaign (1.x) APIs against their equivalent APIs in AEPCampaign (3.x).

If an explanation beyond showing API differences is necessary, it will be captured as a "Note" within that API's section.  

For example:

> **Note**: This is information that is important to help clarify the API.

## Primary class

The class name containing public APIs is different depending on which SDK and language combination being used.

| SDK Version | Language | Class Name | Example |
| ----------- | -------- | ---------- | ------- |
| ACPCampaign | Objective-C | `ACPCampaign` | `[ACPCampaign resetLinkageFields];` |
| AEPCampaign | Objective-C | `AEPMobileCampaign` | `[AEPMobileCampaign resetLinkageFields];` |
| AEPCampaign | Swift | `Campaign` | `Campaign.resetLinkageFields()` |

## Public APIs (alphabetical)
- [extensionVersion](#extensionVersion)
- [registerExtension](#registerExtension)
- [resetLinkageFields](#resetLinkageFields)
- [setLinkageFields](#setLinkageFields)

---

### extensionVersion

**ACPCampaign (Objective-C)**
```objc
+ (nonnull NSString*) extensionVersion;
```

**AEPCampaign (Objective-C)**
```objc
+ (nonnull NSString*) extensionVersion;
```

**AEPCampaign (Swift)**
```swift
static var extensionVersion: String
```

---

### registerExtension

**ACPCampaign (Objective-C)**

```objc
+ (void) registerExtension;
```

**AEPCampaign (Objective-C)**

> **Note**: Registration occurs by passing `AEPMobileCampaign` to the `[AEPMobileCore registerExtensions:completion:]` API.

```objc
[AEPMobileCore registerExtensions:@[AEPMobileCampaign.class] completion:nil];
```

**AEPCampaign (Swift)**

> **Note**: Registration occurs by passing `Campaign` to the `MobileCore.registerExtensions` API.

```swift
MobileCore.registerExtensions([Campaign.self])
```
---

### resetLinkageFields

**ACPCampaign (Objective-C)**

```objc
+ (void) resetLinkageFields;
```

**AEPCampaign (Objective-C)**

```objc
+ (void) resetLinkageFields;
```

**AEPCampaign (Swift)**

```swift
static func resetLinkageFields()
```

---

### setLinkageFields

**ACPCampaign (Objective-C)**

```objc
+ (void) setLinkageFields: (nonnull NSDictionary<NSString*, NSString*>*) linkageFields;
```

**AEPCampaign (Objective-C)**
```objc
+ (void) setLinkageFields: (nonnull NSDictionary<NSString*, NSString*>*) linkageFields;
```

**AEPCampaign (Swift)**

```swift
static func setLinkageFields(linkageFields: [String: String])
```

