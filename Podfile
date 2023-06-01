platform :ios, '11.0'
use_frameworks!

project 'AEPCampaign.xcodeproj'

pod 'SwiftLint', '0.44.0'

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
   pod 'AEPAssurance'
end

def user_profile
   pod 'AEPUserProfile'
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
