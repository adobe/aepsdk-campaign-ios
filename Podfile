platform :ios, '10.0'
use_frameworks!

project 'AEPCampaign.xcodeproj'

pod 'SwiftLint', '0.44.0'

# POD groups

def campaign_core_dependencies
   pod 'AEPCore', :git => 'git@github.com:adobe/aepsdk-core-ios.git'
   pod 'AEPServices', :git => 'git@github.com:adobe/aepsdk-core-ios.git'
   pod 'AEPIdentity', :git => 'git@github.com:adobe/aepsdk-core-ios.git'
end

def rulesengine
   pod 'AEPRulesEngine'
end

def assurance
   pod 'ACPCore', :git => 'git@github.com:adobe/aepsdk-compatibility-ios.git', :branch => 'main'
   pod 'AEPAssurance'
end

def user_profile
   pod 'AEPUserProfile', :git => 'git@github.com:adobe/aepsdk-userprofile-ios.git', :branch => 'main'
end

def places
   pod 'AEPPlaces', :git => 'git@github.com:adobe/aepsdk-places-ios.git', :branch => 'main'
end

def core_additional_dependecies
   pod 'AEPLifecycle', :git => 'git@github.com:adobe/aepsdk-core-ios.git'
   pod 'AEPSignal', :git => 'git@github.com:adobe/aepsdk-core-ios.git'
end

target 'AEPCampaign' do
   campaign_core_dependencies
   rulesengine   
end

target 'AEPCampaignUnitTests' do
   campaign_core_dependencies
   rulesengine
end

target 'AEPCampaignFunctionalTests' do
  campaign_core_dependencies
  rulesengine
  user_profile
  core_additional_dependecies 
end

target 'CampaignTester' do
   campaign_core_dependencies
   rulesengine
   user_profile
   core_additional_dependecies   
   assurance
   places
end
