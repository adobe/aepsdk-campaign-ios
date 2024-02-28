platform :ios, '12.0'
use_frameworks!

project 'AEPCampaign.xcodeproj'

pod 'SwiftLint', '0.52.0'

# POD groups

def campaign_core_dependencies
  pod 'AEPCore', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :branch => 'dev-v5.0.0'
  pod 'AEPServices', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :branch => 'dev-v5.0.0'
  pod 'AEPRulesEngine', :git => 'https://github.com/adobe/aepsdk-rulesengine-ios.git', :branch => 'dev-v5.0.0'
  pod 'AEPIdentity', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :branch => 'dev-v5.0.0'
end

def rulesengine
   pod 'AEPRulesEngine', :git => 'https://github.com/adobe/aepsdk-rulesengine-ios.git', :branch => 'dev-v5.0.0'
end

def assurance   
   pod 'AEPAssurance'
end

def user_profile
   pod 'AEPUserProfile', :git => 'https://github.com/adobe/aepsdk-userprofile-ios.git', :branch => 'dev-v5.0.0'
end

def places
   pod 'AEPPlaces', :git => 'https://github.com/adobe/aepsdk-places-ios.git', :branch => 'dev-v5.0.0'
end

def core_additional_dependecies
   pod 'AEPLifecycle', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :branch => 'dev-v5.0.0'
   pod 'AEPSignal', :git => 'https://github.com/adobe/aepsdk-core-ios.git', :branch => 'dev-v5.0.0'
end

target 'AEPCampaign' do
   campaign_core_dependencies
   rulesengine   
end

target 'AEPCampaignUnitTests' do
   campaign_core_dependencies
   rulesengine
   pod 'AEPTestUtils', :git => 'https://github.com/adobe/aepsdk-testutils-ios.git', :tag => 'v5.0.0-beta'
end

target 'AEPCampaignFunctionalTests' do
  campaign_core_dependencies
  rulesengine
  user_profile
  core_additional_dependecies
  pod 'AEPTestUtils', :git => 'https://github.com/adobe/aepsdk-testutils-ios.git', :tag => 'v5.0.0-beta'
end

target 'CampaignTester' do
   campaign_core_dependencies
   rulesengine
   user_profile
   core_additional_dependecies   
#   assurance
   places
end
