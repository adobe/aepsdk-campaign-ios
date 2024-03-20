platform :ios, '12.0'
use_frameworks!

project 'AEPCampaign.xcodeproj'

pod 'SwiftLint', '0.52.0'

# POD groups

def campaign_core_dependencies
  pod 'AEPCore'
  pod 'AEPServices'  
  pod 'AEPIdentity'
end

def rulesengine
   pod 'AEPRulesEngine'
end

def assurance
   pod 'AEPAssurance', :git => 'https://github.com/adobe/aepsdk-assurance-ios.git', :branch => 'staging'
end

def user_profile
   pod 'AEPUserProfile', :git => 'https://github.com/adobe/aepsdk-userprofile-ios.git', :branch => 'staging'
end

def places
   pod 'AEPPlaces'
end

def core_additional_dependecies
   pod 'AEPLifecycle'
   pod 'AEPSignal'
end

target 'AEPCampaign' do
   campaign_core_dependencies
   rulesengine   
end

target 'AEPCampaignUnitTests' do
   campaign_core_dependencies
   rulesengine
   pod 'AEPTestUtils', :git => 'https://github.com/adobe/aepsdk-testutils-ios.git', :tag => '5.0.0'
end

target 'AEPCampaignFunctionalTests' do
  campaign_core_dependencies
  rulesengine
  user_profile
  core_additional_dependecies
  pod 'AEPTestUtils', :git => 'https://github.com/adobe/aepsdk-testutils-ios.git', :tag => '5.0.0'
end

target 'CampaignTester' do
   campaign_core_dependencies
   rulesengine
   user_profile
   core_additional_dependecies   
#   assurance
   places
end
