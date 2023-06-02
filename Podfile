platform :ios, '11.0'
use_frameworks!

project 'AEPCampaign.xcodeproj'

pod 'SwiftLint', '0.52.0'

# POD groups

def campaign_core_dependencies
   pod 'AEPCore', '~> 4.0'
   pod 'AEPServices', '~> 4.0'
   pod 'AEPIdentity', '~> 4.0'
end

def rulesengine
   pod 'AEPRulesEngine', '~> 4.0'
end

def assurance   
   pod 'AEPAssurance', '~> 4.0'
end

def user_profile
   pod 'AEPUserProfile'
end

def places
   pod 'AEPPlaces'
end

def core_additional_dependecies
   pod 'AEPLifecycle', '~> 4.0'
   pod 'AEPSignal', '~> 4.0'
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
